import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserInfoScreen extends StatelessWidget {
  const UserInfoScreen({super.key});

  // --- Hardcoded Data (Keep constants here) ---
  final String userName = 'Ignacio';
  final String userSex = 'Masculino';
  final String userHeight = '175 cm';
  final String userWeight = '72 kg';
  final String userLocation = 'Madrid';
  final String userBloodType = 'O+';
  final List<String> userAllergies = const ['Polen', 'Penicilina'];
  final String userPhysicalActivity = 'Moderada';
  // --------------------------------------------

  // Helper to calculate age
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // Placeholder for BMI calculation (requires parsing height/weight)
  String _calculateBMI(String heightStr, String weightStr) {
    try {
      double heightCm = double.parse(heightStr.replaceAll(' cm', ''));
      double weightKg = double.parse(weightStr.replaceAll(' kg', ''));
      if (heightCm > 0 && weightKg > 0) {
        double heightM = heightCm / 100;
        double bmi = weightKg / (heightM * heightM);
        String status = "Normal";
        if (bmi < 18.5) status = "Bajo peso";
        if (bmi >= 25 && bmi < 30) status = "Sobrepeso";
        if (bmi >= 30) status = "Obesidad";
        return '${bmi.toStringAsFixed(1)} $status';
      }
    } catch (e) {
      // Handle parsing error
    }
    return 'N/A';
  }


  @override
  Widget build(BuildContext context) {
    // --- Initialize non-const data inside build --- 
    final DateTime userBirthDate = DateTime(1985, 6, 15);
    final DateTime lastUpdate = DateTime(2025, 4, 19, 13, 57);
    // ---------------------------------------------

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final formattedLastUpdate = DateFormat('dd MMM yyyy, HH:mm').format(lastUpdate);
    final age = _calculateAge(userBirthDate);
    final formattedBirthDate = DateFormat('dd/MM/yyyy').format(userBirthDate);
    final bmiString = _calculateBMI(userHeight, userWeight);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mi Perfil'),
             Text(
              'Últ. act: $formattedLastUpdate',
              style: textTheme.bodySmall?.copyWith(color: Colors.white70),
             ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 1.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined), // Or Icons.person_outline
            tooltip: 'Perfil',
            onPressed: () {
              // Maybe refresh? Or stay here?
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildInfoCard(
            context: context,
            title: 'Información Personal',
            icon: Icons.person_outline,
            children: [
              _buildInfoRow(Icons.badge_outlined, 'Nombre', userName),
              _buildInfoRow(Icons.wc_outlined, 'Sexo', userSex),
              _buildInfoRow(Icons.cake_outlined, 'Fecha de nacimiento', '$formattedBirthDate ($age años)'),
              _buildInfoRow(Icons.height_outlined, 'Estatura', userHeight),
              _buildInfoRow(Icons.monitor_weight_outlined, 'Peso', userWeight),
              _buildInfoRow(Icons.scale_outlined, 'IMC Índice de Masa Corporal', bmiString), // Use calculated BMI
              _buildInfoRow(Icons.location_on_outlined, 'Ubicación', userLocation),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context: context,
            title: 'Información Médica',
            icon: Icons.medical_information_outlined, // Or Icons.favorite_border
            children: [
              _buildInfoRow(Icons.bloodtype_outlined, 'Grupo sanguíneo', userBloodType),
              _buildAllergyRow(Icons.warning_amber_outlined, 'Alergias', userAllergies),
              _buildInfoRow(Icons.directions_run_outlined, 'Actividad física', userPhysicalActivity), // Or Icons.fitness_center
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                  onPressed: () {
                    // TODO: Implement edit functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Editar $title no implementado.')),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30), // Adjust size if needed
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

   Widget _buildAllergyRow(IconData icon, String label, List<String> allergies) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
         crossAxisAlignment: CrossAxisAlignment.start, // Align items to top
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))),
          const SizedBox(width: 8),
          if (allergies.isEmpty)
             const Text('-', style: TextStyle(fontWeight: FontWeight.bold))
          else
            Wrap( // Use Wrap for multiple chips
              spacing: 4.0, // Horizontal space between chips
              runSpacing: 4.0, // Vertical space between lines
              alignment: WrapAlignment.end, // Align chips to the right
              children: allergies.map((allergy) => Chip(
                label: Text(allergy),
                backgroundColor: Colors.orange.shade100,
                labelStyle: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              )).toList(),
            ),
        ],
      ),
    );
  }
} 