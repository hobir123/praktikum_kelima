import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UserSpaceApp());
}

// ================= MODEL PENGGUNA =================

class UserModel {
  final int id;
  final String firstName;
  final String lastName;
  final String email;

  const UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

// ================= PENYIMPANAN LOKAL =================

class UserStorage {
  static const String _storageKey = 'users_local_data';

  Future<List<UserModel>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null || savedData.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(savedData);
      return decoded
          .map((item) => UserModel.fromJson(
        Map<String, dynamic>.from(item as Map),
      ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveUsers(List<UserModel> users) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(users.map((user) => user.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }
}

// ================= APLIKASI =================

class UserSpaceApp extends StatelessWidget {
  const UserSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UserSpace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6558D3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const UserListPage(),
    );
  }
}

// ================= HALAMAN DAFTAR =================

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final UserStorage _storage = UserStorage();

  List<UserModel> _users = [];
  bool _loading = true;
  int _nextId = 1;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _storage.getUsers();
      if (!mounted) return;

      setState(() {
        _users = users;
        _nextId = users.isEmpty
            ? 1
            : users.map((user) => user.id).reduce(
              (a, b) => a > b ? a : b,
        ) +
            1;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Gagal membaca data lokal.', error: true);
    }
  }

  Future<void> _saveUsers() async {
    await _storage.saveUsers(_users);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          error ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openForm({UserModel? user}) async {
    final result = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (_) => UserFormPage(
          user: user,
          newId: _nextId,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (user == null) {
        _users.add(result);
        _nextId++;
      } else {
        final index = _users.indexWhere((item) => item.id == user.id);
        if (index != -1) {
          _users[index] = result;
        }
      }
    });

    try {
      await _saveUsers();
      _showMessage(
        user == null
            ? 'Pengguna berhasil ditambahkan.'
            : 'Data pengguna berhasil diperbarui.',
      );
    } catch (_) {
      _showMessage('Gagal menyimpan data.', error: true);
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pengguna?'),
        content: Text('Hapus ${user.fullName} dari daftar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _users.removeWhere((item) => item.id == user.id);
    });

    try {
      await _saveUsers();
      _showMessage('Pengguna berhasil dihapus.');
    } catch (_) {
      _showMessage('Gagal menyimpan perubahan.', error: true);
    }
  }

  Future<void> _clearUsers() async {
    if (_users.isEmpty) {
      _showMessage('Daftar pengguna sudah kosong.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kosongkan semua data?'),
        content: const Text(
          'Semua pengguna yang tersimpan di aplikasi ini akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _users.clear();
      _nextId = 1;
    });

    try {
      await _saveUsers();
      _showMessage('Semua data pengguna berhasil dihapus.');
    } catch (_) {
      _showMessage('Gagal menyimpan perubahan.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UserSpace',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Manajemen pengguna lokal',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kosongkan semua data',
            onPressed: _clearUsers,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tambah User'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6558D3),
                    Color(0xFF9B72CF),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelola pengguna',
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Data User',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tambah, edit, dan hapus data',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 55,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daftar Pengguna',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(label: Text('${_users.length} pengguna')),
              ],
            ),
            const SizedBox(height: 10),
            if (_users.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 68,
                      color: Color(0xFF6558D3),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada pengguna',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tekan tombol Tambah User untuk memasukkan '
                          'data pengguna baru.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              )
            else
              ..._users.map(_userCard),
          ],
        ),
      ),
    );
  }

  Widget _userCard(UserModel user) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE8E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFE8E5FF),
          child: Text(
            user.fullName.isEmpty
                ? '?'
                : user.fullName[0].toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF6558D3),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${user.email}\nID: ${user.id}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _openForm(user: user);
            if (value == 'delete') _deleteUser(user);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Hapus'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= FORM PENGGUNA =================

class UserFormPage extends StatefulWidget {
  final UserModel? user;
  final int newId;

  const UserFormPage({
    super.key,
    this.user,
    required this.newId,
  });

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();

    _firstNameController = TextEditingController(
      text: widget.user?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.user?.lastName ?? '',
    );
    _emailController = TextEditingController(
      text: widget.user?.email ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final user = UserModel(
      id: widget.user?.id ?? widget.newId,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
    );

    Navigator.pop(context, user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Pengguna' : 'Tambah Pengguna'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 46,
                        color: Color(0xFF6558D3),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Informasi Pengguna',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Lengkapi data pengguna di bawah ini'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _field(
                  controller: _firstNameController,
                  label: 'Nama depan',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _lastNameController,
                  label: 'Nama belakang',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Email wajib diisi';

                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email)) {
                      return 'Masukkan email yang valid';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(
                    _isEditing ? Icons.save_outlined : Icons.add,
                  ),
                  label: Text(
                    _isEditing ? 'Simpan Perubahan' : 'Simpan Pengguna',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      validator: validator ??
              (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label wajib diisi';
            }
            return null;
          },
    );
  }
}
