import 'package:flutter/material.dart';
import 'profile_widget.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    bool usePushReplacement = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        if (usePushReplacement) {
          Navigator.pushReplacementNamed(context, route);
        } else {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor:
          const Color(0xFF2C3E50), // Match the dark blue-gray color
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(
            height: 120,
            child: ProfileWidget(),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.people,
            title: 'Usuarios',
            route: '/users',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.article,
            title: 'Documentos',
            route: '/documentos',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.contacts,
            title: 'Contactos 1',
            route: '/contact1',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.contacts,
            title: 'Contactos 2',
            route: '/contact2',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.contacts,
            title: 'Contactos 3',
            route: '/contact3',
          ),
          const Divider(color: Colors.white24),
          _buildDrawerItem(
            context: context,
            icon: Icons.draw,
            title: 'Demo Firma Digital',
            route: '/signature-demo',
            usePushReplacement: false,
          ),
        ],
      ),
    );
  }
}
