import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

final userManagementProvider = Provider<UserManagement>(
  (ref) => UserManagement(),
);

class UserManagement {
  final _supabase = Supabase.instance.client;

  // Generate a secure random password
  String _generateRandomPassword({int length = 12}) {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const special = '@#%^*+\$';

    final allChars = letters + numbers + special;
    final random = Random.secure();

    // Ensure password contains at least one of each character type
    final passwordChars = [
      letters[random.nextInt(letters.length)],
      numbers[random.nextInt(numbers.length)],
      special[random.nextInt(special.length)],
    ];

    // Fill the rest with random characters
    for (var i = 3; i < length; i++) {
      passwordChars.add(allChars[random.nextInt(allChars.length)]);
    }

    // Shuffle the characters
    passwordChars.shuffle(random);

    return passwordChars.join();
  }

  // Get all users
  Future<List<AppUser>> getAllUsers() async {
    final response = await _supabase
        .from('profiles')
        .select('*')
        .order('created_at', ascending: false);

    return (response as List).map((user) => AppUser.fromJson(user)).toList();
  }

  // Add new user with generated password
  Future<({String userId, String generatedPassword})>
  addUserWithGeneratedPassword({
    required String email,
    required String fullName,
    required String phone,
    required String role,
    required List<String> locations,
  }) async {
    // Generate a secure password
    final generatedPassword = _generateRandomPassword();

    // First create auth user
    final authResponse = await _supabase.auth.signUp(
      email: email,
      password: generatedPassword,
    );

    if (authResponse.user == null) {
      throw Exception('User creation failed');
    }

    // Then create profile with the generated password
    await _supabase.from('profiles').upsert({
      'id': authResponse.user!.id,
      'email': email,
      'name': fullName,
      'phone': phone,
      'role': role,
      'initial_password': generatedPassword,
      'locations': locations,
    });

    return (
      userId: authResponse.user!.id,
      generatedPassword: generatedPassword,
    );
  }

  // Update user
  Future<void> updateUser({
    required String userId,
    String? fullName,
    String? phone,
    String? role,
    List<String>? locations,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (role != null) updates['role'] = role;
    if (locations != null) updates['locations'] = locations;

    if (updates.isNotEmpty) {
      await _supabase.from('profiles').update(updates).eq('id', userId);
    }
  }

  // Delete user
 Future<void> deleteUser(String userId) async {
  try {
    // This will only succeed if the executing user is an admin
    // due to our RLS policy
    final response = await _supabase
        .from('profiles')
        .delete()
        .eq('id', userId)
        .select();

    if (response.isEmpty) {
      throw Exception('User not found or not authorized');
    }
    
    // Optional: Also delete from auth.users if needed
    try {
      await _supabase.auth.admin.deleteUser(userId);
    } catch (e) {
      print('Could not delete auth user: $e');
    }
  } catch (e) {
    throw Exception('Failed to delete user: ${e.toString()}');
  }
}

  // Reset user password
  Future<String> resetUserPassword(String userId) async {
    final generatedPassword = _generateRandomPassword();

    await _supabase.auth.admin.updateUserById(
      userId,
      attributes: AdminUserAttributes(password: generatedPassword),
    );

    await _supabase
        .from('profiles')
        .update({'initial_password': generatedPassword})
        .eq('id', userId);

    return generatedPassword;
  }

  // Get user initial password
  Future<String?> getUserInitialPassword(String userId) async {
    final response =
        await _supabase
            .from('profiles')
            .select('initial_password')
            .eq('id', userId)
            .single();

    return response['initial_password'] as String?;
  }

  // Get available locations
  Future<List<String>> getAvailableLocations() async {
    final response = await _supabase
        .from('locations')
        .select('name')
        .order('name', ascending: true);

    return (response as List).map((loc) => loc['name'] as String).toList();
  }
}
