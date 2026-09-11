import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math'; // Required for Fuzzy Search Math
import '../../../models/product_model.dart';
import '../home/widgets/product_card.dart';
import '../home/providers/products_provider.dart';

// 1. The Riverpod State to remember search history
final searchHistoryProvider = StateProvider<List<String>>((ref) => []);

class SearchScreen extends ConsumerStatefulWidget {
  // === FIX: Added initialQuery to catch tags from Action Banners ===
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ""});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _searchQuery = "";
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // === FIX: Initialize with the custom tag if provided ===
    _searchQuery = widget.initialQuery;
    _searchController = TextEditingController(text: widget.initialQuery);

    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitSearch(widget.initialQuery);
      });
    }
  }

  void _submitSearch(String query) {
    if (query.trim().isNotEmpty) {
      final history = ref.read(searchHistoryProvider);
      final newHistory = [query, ...history.where((q) => q != query)].take(5).toList();
      ref.read(searchHistoryProvider.notifier).state = newHistory;
      FocusScope.of(context).unfocus(); // Close keyboard
    }
  }

  // === NEW: LEVENSHTEIN DISTANCE ALGORITHM (TYPO CALCULATOR) ===
  int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.filled(b.length + 1, 0);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i <= b.length; i++) v0[i] = i;

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= b.length; j++) v0[j] = v1[j];
    }
    return v1[b.length];
  }

  // === NEW: FUZZY MATCHER LOGIC ===
  bool _fuzzyMatch(String query, String target) {
    query = query.toLowerCase().trim();
    target = target.toLowerCase().trim();

    // 1. Direct Match (Always fastest)
    if (target.contains(query)) return true;

    // 2. Typo Match (Breaks sentences into words and checks distance)
    List<String> queryWords = query.split(RegExp(r'\s+'));
    List<String> targetWords = target.split(RegExp(r'\s+'));

    for (String qWord in queryWords) {
      if (qWord.length < 2) continue; // Skip single letters to prevent false positives

      for (String tWord in targetWords) {
        int distance = _levenshteinDistance(qWord, tWord);
        // If the typo distance is 2 or less, and it's not replacing the entire word, it's a match!
        if (distance <= 2 && distance < tWord.length) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final liveProductsAsync = ref.watch(productsStreamProvider);
    final allProducts = liveProductsAsync.value ?? [];

    List<ProductModel> searchResults = [];

    if (_searchQuery.isNotEmpty) {
      searchResults = allProducts.where((product) {
        // === SMART FUZZY SEARCH ACTIVATED ===
        final nameMatch = _fuzzyMatch(_searchQuery, product.name);
        final categoryMatch = _fuzzyMatch(_searchQuery, product.category);
        final keywordMatch = _fuzzyMatch(_searchQuery, product.keywords);

        return nameMatch || categoryMatch || keywordMatch;
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: TextField(
          controller: _searchController,
          autofocus: widget.initialQuery.isEmpty, // Only autofocus if user clicked search manually
          onChanged: (val) => setState(() => _searchQuery = val),
          onSubmitted: _submitSearch,
          decoration: InputDecoration(
            hintText: 'Search wholesale kirana...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            )
                : null,
          ),
        ),
      ),
      body: _searchQuery.isEmpty
          ? _buildHistoryAndSuggestions()
          : searchResults.isEmpty
          ? _buildNoResults()
          : _buildResultsGrid(searchResults),
    );
  }

  Widget _buildResultsGrid(List<ProductModel> results) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => ProductCard(product: results[index]),
    );
  }

  Widget _buildHistoryAndSuggestions() {
    final history = ref.watch(searchHistoryProvider);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Searches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => ref.read(searchHistoryProvider.notifier).state = [],
                child: const Text('Clear', style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: history.map((term) => InputChip(
              label: Text(term, style: const TextStyle(fontSize: 13)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                ref.read(searchHistoryProvider.notifier).state = history.where((t) => t != term).toList();
              },
              onPressed: () {
                _searchController.text = term;
                setState(() => _searchQuery = term);
              },
              backgroundColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[300]!)),
            )).toList(),
          ),
          const Divider(height: 32),
        ],

        const Text('Trending in Bhiwandi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Cashews', 'Rice', 'Oil', 'Sugar'].map((tag) {
            return ActionChip(
              label: Text(tag, style: const TextStyle(fontSize: 13)),
              backgroundColor: Colors.blue[50],
              side: BorderSide(color: Colors.blue[100]!),
              onPressed: () {
                _searchController.text = tag;
                setState(() => _searchQuery = tag);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No wholesale items match "$_searchQuery"', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}