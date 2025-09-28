import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key});

  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showProfileMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final screenSize = MediaQuery.of(context).size;

    // Get the position of the profile widget
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    // Calculate menu dimensions based on screen size
    final menuWidth = screenSize.width * 0.5; // 50% of screen width, max 300
    final menuHeight = 110.0; // Height needed for 2 menu items
    final padding = 8.0;

    // Calculate vertical position below the role text
    final menuTop = buttonPosition.dy + 60 + 20; // Below role text

    // Calculate horizontal position - center under profile info
    double menuLeft =
        buttonPosition.dx + (button.size.width / 2) - (menuWidth / 2);

    // Ensure menu stays within screen bounds
    if (menuLeft < padding) {
      menuLeft = padding;
    } else if (menuLeft + menuWidth > screenSize.width - padding) {
      menuLeft = screenSize.width - menuWidth - padding;
    }

    // Calculate available space below the button
    final availableSpaceBelow = screenSize.height - menuTop - padding;
    final menuTopAdjusted = availableSpaceBelow < menuHeight
        ? buttonPosition.dy -
            menuHeight -
            padding // Show above if not enough space below
        : menuTop;

    final position = RelativeRect.fromLTRB(
      menuLeft,
      menuTopAdjusted,
      menuLeft + menuWidth,
      menuTopAdjusted + menuHeight,
    );


    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person, size: 18),
              SizedBox(width: 8),
              Text('Perfil'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 8),
              Text('Cerrar Sesión'),
            ],
          ),
        ),
      ],
    ).then((String? result) {
      if (result != null) {
        _handleMenuAction(result);
      }
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'profile':
        // Navigate to profile screen or show profile dialog
        _showProfileDialog();
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  void _showProfileDialog() {
    // Navigate to profile screen instead of showing modal
    Navigator.of(context).pushNamed('/profile');
  }

  Future<void> _logout() async {
    try {
      final authService = AuthService();
      await authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cerrar sesión')),
        );
      }
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: const Text(
          'Error al cargar usuario',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF2C3E50), // Dark blue-gray color similar to your image
      ),
      child: Row(
        children: [
          // Avatar circle with initials (non-clickable)
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF1ABC9C), // Teal color for avatar
            child: Text(
              _getInitials(_currentUser!['nombre']),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // User info (non-clickable)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentUser!['nombre'] ?? 'Usuario',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentUser!['rol'] ?? 'user',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Menu button (clickable)
          GestureDetector(
            onTap: () => _showProfileMenu(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.more_vert,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
