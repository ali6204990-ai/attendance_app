import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  final Widget Function() homeBuilder;

  const LoginPage({super.key, required this.homeBuilder});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController employeeNumberController =
      TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  Future<void> login() async {
    final employeeNumber = employeeNumberController.text.trim();
    final password = passwordController.text;

    if (employeeNumber.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الرقم الوطني وكلمة المرور')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final supabase = Supabase.instance.client;

    try {
      // تحويل الرقم الوطني إلى البريد الداخلي
      final email =
          '$employeeNumber@employees.rbnktsiuimiuvlsukhcc.supabase.co';

      // تسجيل الدخول عبر Supabase Auth
      final session = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // جلب بيانات الموظف نفسه فقط
      final employee = await supabase
          .from('employees')
          .select('employee_number, full_name, is_active')
          .eq('id', session.user!.id)
          .eq('employee_number', employeeNumber)
          .maybeSingle();

      if (!mounted) return;

      // التأكد من وجود سجل الموظف
      if (employee == null) {
        await supabase.auth.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على بيانات الموظف')),
        );
        return;
      }

      // التحقق من نشاط الحساب
      if (employee['is_active'] != true) {
        await supabase.auth.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حساب الموظف غير نشط، يرجى مراجعة الإدارة'),
          ),
        );
        return;
      }

      // الانتقال إلى شاشة الحضور
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.homeBuilder()),
      );
     } on AuthException catch (e) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('خطأ تسجيل الدخول: ${e.message}'),
      duration: const Duration(seconds: 8),
    ),
  );
   } catch (e) {
      await supabase.auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر إتمام تسجيل الدخول. تحقق من الاتصال وحاول مجدداً.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    employeeNumberController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        appBar: AppBar(
          title: const Text('تسجيل الدخول'),
          backgroundColor: const Color(0xFF145A46),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 30),
                const Icon(
                  Icons.account_circle,
                  size: 100,
                  color: Color(0xFF145A46),
                ),
                const SizedBox(height: 20),
                const Text(
                  'مرحباً بك',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF145A46),
                  ),
                ),
                const SizedBox(height: 35),

                TextField(
                  controller: employeeNumberController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'الرقم الوطني',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: passwordController,
                  enabled: !isLoading,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!isLoading) login();
                  },
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : login,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      isLoading ? 'جارٍ تسجيل الدخول...' : 'تسجيل الدخول',
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF145A46),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
