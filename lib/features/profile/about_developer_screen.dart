import 'package:flutter/material.dart';

class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Soft premium background
      appBar: AppBar(
        title: const Text('Developer Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true, // Allows the gradient to flow under the app bar
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. PREMIUM HERO SECTION ---
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Curved Gradient Background
                Container(
                  margin: const EdgeInsets.only(bottom: 50),
                  height: 240,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3C72), Color(0xFF2A5298)], // Deep elegant blue
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),
                // Floating Profile Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  padding: const EdgeInsets.all(6), // Creates a white border effect
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: const Color(0xFFF0F4F8),
                    child: Icon(Icons.assignment_ind, size: 50, color: Colors.blue[800]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Text('Sohail Kachhi', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5)),
            const SizedBox(height: 6),

            // Subtle Title Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)
              ),
              child: const Text('Senior Software Architect', style: TextStyle(fontSize: 14, color: Colors.blueAccent, fontWeight: FontWeight.w700)),
            ),

            const SizedBox(height: 35),

            // --- 2. EXPERIENCE STATS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildStatCard('70+', 'Apps Built', Icons.smartphone_rounded, const Color(0xFF4A90E2)),
                  const SizedBox(width: 16),
                  _buildStatCard('364+', 'Websites', Icons.language_rounded, const Color(0xFF673AB7)),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // --- 3. ABOUT & TECH STACK ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The Vision', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 12),
                  const Text(
                    'I transform complex business requirements into high-performance digital ecosystems. Specializing in scalable Flutter architectures and robust cloud backends to engineer your vision for scale.',
                    style: TextStyle(color: Color(0xFF666666), height: 1.6, fontSize: 15),
                  ),

                  const SizedBox(height: 24),
                  // Tech Stack Chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildTechChip('Flutter'),
                      _buildTechChip('Dart'),
                      _buildTechChip('Firebase'),
                      _buildTechChip('UI/UX Design'),
                      _buildTechChip('Cloud Architecture'),
                    ],
                  ),

                  const SizedBox(height: 40),
                  const Text('Get in Touch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 16),

                  // --- 4. PREMIUM CONTACT CARDS ---
                  _buildPremiumContactRow(Icons.email_rounded, 'Email Address', 'sohailkachhi88@gmail.com', const Color(0xFFE57373)),
                  _buildPremiumContactRow(Icons.chat_rounded, 'WhatsApp', '+91 9112050119', const Color(0xFF81C784)),
                  _buildPremiumContactRow(Icons.camera_alt_rounded, 'Instagram', '@Sohail_memon_120', const Color(0xFFBA68C8)),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String count, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8)),
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 16),
            Text(count, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildTechChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87)),
    );
  }

  Widget _buildPremiumContactRow(IconData icon, String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.withOpacity(0.4), size: 16),
        ],
      ),
    );
  }
}