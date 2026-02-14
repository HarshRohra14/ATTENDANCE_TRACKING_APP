import 'package:flutter/material.dart';

void main() {
  runApp(const AttendanceApp());
}

enum UserRole { student, teacher, admin }

enum ObjectionStatus { pending, approved, rejected }

class AppUser {
  AppUser({
    required this.username,
    required this.password,
    required this.role,
    this.studentName,
  });

  final String username;
  final String password;
  final UserRole role;
  final String? studentName;
}

class AttendanceEntry {
  AttendanceEntry({required this.date, required this.present});

  final DateTime date;
  final bool present;
}

class ObjectionRequest {
  ObjectionRequest({
    required this.id,
    required this.studentName,
    required this.eventName,
    required this.reason,
    required this.requestedSessions,
    this.status = ObjectionStatus.pending,
  });

  final String id;
  final String studentName;
  final String eventName;
  final String reason;
  final int requestedSessions;
  ObjectionStatus status;
}

class StudentProfile {
  StudentProfile({required this.name});

  final String name;
  final List<AttendanceEntry> attendance = [];
  int creditedSessions = 0;

  int get presentCount => attendance.where((entry) => entry.present).length;

  int get totalCount => attendance.length;

  double get percentage {
    if (totalCount == 0) {
      return 0;
    }
    final computed = ((presentCount + creditedSessions) / totalCount) * 100;
    return computed.clamp(0, 100);
  }
}

class AppState extends ChangeNotifier {
  AppState() {
    _seed();
  }

  final List<AppUser> users = [];
  final Map<String, StudentProfile> students = {};
  final List<ObjectionRequest> objections = [];

  AppUser? currentUser;

  void _seed() {
    users.addAll([
      AppUser(username: 'admin', password: 'admin123', role: UserRole.admin),
      AppUser(username: 'teacher1', password: 'teacher123', role: UserRole.teacher),
      AppUser(
        username: 'student1',
        password: 'student123',
        role: UserRole.student,
        studentName: 'Aarav',
      ),
      AppUser(
        username: 'student2',
        password: 'student123',
        role: UserRole.student,
        studentName: 'Diya',
      ),
    ]);

    students['Aarav'] = StudentProfile(name: 'Aarav')
      ..attendance.addAll([
        AttendanceEntry(date: DateTime.now().subtract(const Duration(days: 2)), present: true),
        AttendanceEntry(date: DateTime.now().subtract(const Duration(days: 1)), present: false),
      ]);

    students['Diya'] = StudentProfile(name: 'Diya')
      ..attendance.addAll([
        AttendanceEntry(date: DateTime.now().subtract(const Duration(days: 2)), present: true),
        AttendanceEntry(date: DateTime.now().subtract(const Duration(days: 1)), present: true),
      ]);
  }

  bool login(String username, String password) {
    final user = users
        .where((candidate) => candidate.username == username && candidate.password == password)
        .firstOrNull;
    if (user == null) {
      return false;
    }

    currentUser = user;
    notifyListeners();
    return true;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  bool addUser({
    required String username,
    required String password,
    required UserRole role,
    String? studentName,
  }) {
    final exists = users.any((user) => user.username.toLowerCase() == username.toLowerCase());
    if (exists) {
      return false;
    }

    if (role == UserRole.student && (studentName == null || studentName.trim().isEmpty)) {
      return false;
    }

    final normalizedStudentName = studentName?.trim();
    users.add(
      AppUser(
        username: username.trim(),
        password: password,
        role: role,
        studentName: normalizedStudentName,
      ),
    );

    if (role == UserRole.student && normalizedStudentName != null) {
      students.putIfAbsent(normalizedStudentName, () => StudentProfile(name: normalizedStudentName));
    }

    notifyListeners();
    return true;
  }

  void markAttendance({
    required String studentName,
    required DateTime date,
    required bool present,
  }) {
    final profile = students[studentName];
    if (profile == null) {
      return;
    }

    final dateKey = DateTime(date.year, date.month, date.day);
    final existingIndex = profile.attendance.indexWhere((entry) {
      final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      return entryDate == dateKey;
    });

    if (existingIndex >= 0) {
      profile.attendance[existingIndex] = AttendanceEntry(date: dateKey, present: present);
    } else {
      profile.attendance.add(AttendanceEntry(date: dateKey, present: present));
    }

    profile.attendance.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  void submitObjection({
    required String studentName,
    required String eventName,
    required String reason,
    required int requestedSessions,
  }) {
    objections.insert(
      0,
      ObjectionRequest(
        id: '${DateTime.now().millisecondsSinceEpoch}-$studentName',
        studentName: studentName,
        eventName: eventName,
        reason: reason,
        requestedSessions: requestedSessions,
      ),
    );
    notifyListeners();
  }

  void updateObjectionStatus(String objectionId, ObjectionStatus status) {
    final objection = objections.where((item) => item.id == objectionId).firstOrNull;
    if (objection == null || objection.status != ObjectionStatus.pending) {
      return;
    }

    objection.status = status;

    if (status == ObjectionStatus.approved) {
      final profile = students[objection.studentName];
      if (profile != null) {
        profile.creditedSessions += objection.requestedSessions;
      }
    }

    notifyListeners();
  }

  StudentProfile? currentStudentProfile() {
    final studentName = currentUser?.studentName;
    if (studentName == null) {
      return null;
    }
    return students[studentName];
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }
}

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  final AppState appState = AppState();

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: appState,
      child: MaterialApp(
        title: 'Attendance Tracking',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const RootScreen(),
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final user = state.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return switch (user.role) {
      UserRole.student => StudentDashboard(user: user),
      UserRole.teacher => TeacherDashboard(user: user),
      UserRole.admin => AdminDashboard(user: user),
    };
  }
}

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton.icon(
            onPressed: state.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? error;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Attendance Tracking App',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final ok = state.login(
                        usernameController.text.trim(),
                        passwordController.text,
                      );
                      if (!ok) {
                        setState(() {
                          error = 'Invalid username or password';
                        });
                      }
                    },
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Demo creds: admin/admin123, teacher1/teacher123, student1/student123'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final eventController = TextEditingController();
  final reasonController = TextEditingController();
  final sessionsController = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final profile = state.currentStudentProfile();

    if (profile == null) {
      return const ShellScaffold(
        title: 'Student Dashboard',
        child: Center(child: Text('Student profile not found.')),
      );
    }

    final myObjections = state.objections.where((item) => item.studentName == profile.name).toList();

    return ShellScaffold(
      title: 'Student Dashboard (${profile.name})',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attendance Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Total classes: ${profile.totalCount}'),
                  Text('Present: ${profile.presentCount}'),
                  Text('Credited sessions (approved objections): ${profile.creditedSessions}'),
                  Text('Final percentage: ${profile.percentage.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Raise Attendance Objection', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: eventController,
                    decoration: const InputDecoration(labelText: 'Event name (e.g. Hackathon)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Reason/justification'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sessionsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sessions to be credited'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final sessions = int.tryParse(sessionsController.text) ?? 0;
                      if (eventController.text.trim().isEmpty ||
                          reasonController.text.trim().isEmpty ||
                          sessions <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fill all fields with valid values.')),
                        );
                        return;
                      }

                      state.submitObjection(
                        studentName: profile.name,
                        eventName: eventController.text.trim(),
                        reason: reasonController.text.trim(),
                        requestedSessions: sessions,
                      );

                      eventController.clear();
                      reasonController.clear();
                      sessionsController.text = '1';

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Objection submitted for review.')),
                      );
                    },
                    child: const Text('Submit objection'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My objections', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (myObjections.isEmpty)
                    const Text('No objections submitted yet.')
                  else
                    ...myObjections.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${item.eventName} (+${item.requestedSessions})'),
                        subtitle: Text(item.reason),
                        trailing: Text(item.status.name.toUpperCase()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String? selectedStudent;
  DateTime selectedDate = DateTime.now();
  bool present = true;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final studentNames = state.students.keys.toList()..sort();
    selectedStudent ??= studentNames.isNotEmpty ? studentNames.first : null;

    return ShellScaffold(
      title: 'Teacher Dashboard',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Track Attendance', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStudent,
                    decoration: const InputDecoration(labelText: 'Student'),
                    items: studentNames
                        .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedStudent = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Pick date'),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    value: present,
                    title: const Text('Present'),
                    onChanged: (value) => setState(() => present = value),
                  ),
                  FilledButton(
                    onPressed: selectedStudent == null
                        ? null
                        : () {
                            state.markAttendance(
                              studentName: selectedStudent!,
                              date: selectedDate,
                              present: present,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Attendance saved.')),
                            );
                          },
                    child: const Text('Save attendance'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pending Objections', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...state.objections.where((item) => item.status == ObjectionStatus.pending).map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item.studentName}: ${item.eventName} (+${item.requestedSessions})'),
                      subtitle: Text(item.reason),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => state.updateObjectionStatus(item.id, ObjectionStatus.approved),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => state.updateObjectionStatus(item.id, ObjectionStatus.rejected),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!state.objections.any((item) => item.status == ObjectionStatus.pending))
                    const Text('No pending objections.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final studentNameController = TextEditingController();
  UserRole selectedRole = UserRole.student;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return ShellScaffold(
      title: 'Admin Dashboard',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Provide Credentials', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: UserRole.values
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (selectedRole == UserRole.student)
                    TextField(
                      controller: studentNameController,
                      decoration: const InputDecoration(labelText: 'Student full name'),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      if (usernameController.text.trim().isEmpty ||
                          passwordController.text.isEmpty ||
                          (selectedRole == UserRole.student &&
                              studentNameController.text.trim().isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please complete required fields.')),
                        );
                        return;
                      }

                      final created = state.addUser(
                        username: usernameController.text,
                        password: passwordController.text,
                        role: selectedRole,
                        studentName:
                            selectedRole == UserRole.student ? studentNameController.text : null,
                      );

                      if (created) {
                        usernameController.clear();
                        passwordController.clear();
                        studentNameController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Credentials created successfully.')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Unable to create user (maybe duplicate username).')),
                        );
                      }
                    },
                    child: const Text('Create credentials'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registered Users', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...state.users.map(
                    (user) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(user.username),
                      subtitle: Text(
                        user.role == UserRole.student && user.studentName != null
                            ? '${user.role.name.toUpperCase()} · ${user.studentName}'
                            : user.role.name.toUpperCase(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
