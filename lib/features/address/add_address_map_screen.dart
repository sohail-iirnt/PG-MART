import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddAddressMapScreen extends ConsumerStatefulWidget {
  const AddAddressMapScreen({super.key});

  @override
  ConsumerState<AddAddressMapScreen> createState() => _AddAddressMapScreenState();
}

class _AddAddressMapScreenState extends ConsumerState<AddAddressMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng _centerPosition = const LatLng(19.2813, 73.0483); // Default to Bhiwandi

  bool _isLoading = true;
  bool _isDragging = false;
  bool _isSaving = false;
  bool _showDetailsForm = false; // Toggles the manual entry form

  String _currentAddress = "Locating...";
  String _currentCity = "";
  bool _isServiceable = true;

  // Manual Form Controllers
  final _houseNoCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _manualAddressCtrl = TextEditingController();
  String _selectedTitle = 'Home';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _houseNoCtrl.dispose();
    _landmarkCtrl.dispose();
    _manualAddressCtrl.dispose();
    super.dispose();
  }

  // === 1. GET USER GPS LOCATION ===
  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("Please enable GPS/Location services.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("Location permissions denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError("Location permissions permanently denied. Please enable in settings.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        _centerPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    }

    _updateAddressFromLatLng(_centerPosition);
    _moveCameraTo(_centerPosition);
  }

  Future<void> _moveCameraTo(LatLng target) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)));
  }

  // === 2. TRANSLATE GPS TO TEXT & GEOFENCE ===
  Future<void> _updateAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        String street = place.street ?? '';
        String subLocality = place.subLocality ?? '';
        String city = place.locality ?? '';
        String postalCode = place.postalCode ?? '';

        String fullAddress = "$street, $subLocality, $city, $postalCode";

        // Geofencing Logic
        bool serviceable = city.toLowerCase().contains('bhiwandi') ||
            subLocality.toLowerCase().contains('bhiwandi') ||
            postalCode.startsWith('4213');

        setState(() {
          _currentAddress = fullAddress.replaceAll(', ,', ', ').trim();
          _manualAddressCtrl.text = _currentAddress; // Pre-fill manual text box
          _currentCity = city;
          _isServiceable = serviceable;
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = "Unknown Location (Drag pin to retry)";
        _manualAddressCtrl.text = "";
      });
    }
  }

  // === 3. SAVE TO FIREBASE (FIXED FOR PROVIDER + GEOFENCE OVERRIDE BLOCK) ===
  Future<void> _saveFinalAddress() async {
    if (_houseNoCtrl.text.trim().isEmpty || _manualAddressCtrl.text.trim().isEmpty) {
      _showError('Please enter your House/Flat No. and Area Address.');
      return;
    }

    // === NEW: STRICT GEOFENCE ENFORCEMENT ON FINAL SAVE ===
    final checkAddress = _manualAddressCtrl.text.toLowerCase();
    if (!checkAddress.contains('bhiwandi') && !checkAddress.contains('4213')) {
      _showError('Delivery is currently restricted strictly to Bhiwandi (or pincodes starting with 4213). Please adjust your area.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {

        String finalFormattedAddress = "${_houseNoCtrl.text.trim()}, ";
        if (_landmarkCtrl.text.trim().isNotEmpty) {
          finalFormattedAddress += "Near ${_landmarkCtrl.text.trim()}, ";
        }
        finalFormattedAddress += _manualAddressCtrl.text.trim();

        // The Fix: Saving to the 'addresses' subcollection so the Provider instantly reads it
        final newAddressData = {
          'title': _selectedTitle,
          'fullAddress': finalFormattedAddress,
          'phone': user.phoneNumber ?? '',
          'lat': _centerPosition.latitude,
          'lng': _centerPosition.longitude,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .add(newAddressData);

        if (mounted) {
          Navigator.pop(context); // Go back to Address List
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address Saved Successfully!'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      _showError(e.toString());
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showDetailsForm ? 'Enter Address Details' : 'Set Delivery Location', style: const TextStyle(color: Colors.black, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_showDetailsForm) {
              setState(() => _showDetailsForm = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // === THE GOOGLE MAP ===
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _centerPosition, zoom: 16),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: !_showDetailsForm,
            zoomGesturesEnabled: !_showDetailsForm,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onCameraMoveStarted: () {
              if (!_showDetailsForm) setState(() => _isDragging = true);
            },
            onCameraMove: (position) {
              if (!_showDetailsForm) _centerPosition = position.target;
            },
            onCameraIdle: () {
              if (!_showDetailsForm) {
                setState(() => _isDragging = false);
                _updateAddressFromLatLng(_centerPosition);
              }
            },
          ),

          // === THE FLOATING PIN ===
          if (!_showDetailsForm)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.translationValues(0, _isDragging ? -15 : 0, 0),
                  child: const Icon(Icons.location_on, size: 50, color: Colors.black),
                ),
              ),
            ),

          // === CURRENT LOCATION BUTTON ===
          if (!_showDetailsForm)
            Positioned(
              bottom: 250, // Lifted slightly to make room for bottom sheet
              right: 16,
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                child: Icon(Icons.my_location, color: Theme.of(context).primaryColor),
                onPressed: _getUserLocation,
              ),
            ),

          // === THE DYNAMIC BOTTOM SHEET ===
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))]
              ),
              child: _showDetailsForm ? _buildManualDetailsForm() : _buildMapConfirmSheet(),
            ),
          )
        ],
      ),
    );
  }

  // === UI: STEP 1 (MAP CONFIRMATION & MANUAL OVERRIDE) ===
  Widget _buildMapConfirmSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_isServiceable ? Icons.check_circle : Icons.error, color: _isServiceable ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isServiceable ? 'Delivery Available' : 'Out of Delivery Zone',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isServiceable ? Colors.green[800] : Colors.red[800]),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        Text(_currentAddress, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),

        if (!_isServiceable) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
            child: Text(
              'We are not currently functional in ${_currentCity.isEmpty ? "this area" : _currentCity.toUpperCase()}, but we will be coming there soon!',
              style: TextStyle(color: Colors.red[900], fontSize: 13, fontWeight: FontWeight.w500),
            ),
          )
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isServiceable ? Theme.of(context).primaryColor : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_isServiceable) ? () => setState(() => _showDetailsForm = true) : null,
            child: Text(
              _isServiceable ? 'CONFIRM LOCATION' : 'NOT SERVICEABLE HERE',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // === THE MANUAL OVERRIDE BUTTON ===
        Center(
          child: TextButton(
            onPressed: () {
              // Open the form directly, allowing them to type their address manually
              setState(() => _showDetailsForm = true);
            },
            child: Text('Enter Address Manually Instead', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }

  // === UI: STEP 2 (MANUAL ENTRY FORM) ===
  Widget _buildManualDetailsForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Complete your address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Manual Edit of the Map Area
        TextField(
          controller: _manualAddressCtrl,
          decoration: const InputDecoration(labelText: 'Area / Street / Locality *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
        ),
        const SizedBox(height: 12),

        // House No
        TextField(
          controller: _houseNoCtrl,
          decoration: const InputDecoration(labelText: 'House / Flat / Block No. *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.door_front_door_outlined)),
        ),
        const SizedBox(height: 12),

        // Landmark
        TextField(
          controller: _landmarkCtrl,
          decoration: const InputDecoration(labelText: 'Landmark (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.flag_outlined)),
        ),
        const SizedBox(height: 20),

        // Save As Tags
        const Text('Save As', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: ['Home', 'Work', 'Other'].map((title) {
            final isSelected = _selectedTitle == title;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChoiceChip(
                label: Text(title),
                selected: isSelected,
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                labelStyle: TextStyle(color: isSelected ? Theme.of(context).primaryColor : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                onSelected: (val) => setState(() => _selectedTitle = title),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSaving ? null : _saveFinalAddress,
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('SAVE ADDRESS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
          ),
        )
      ],
    );
  }
}