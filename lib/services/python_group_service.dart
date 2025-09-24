// Create this as a new file: services/python_group_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class PythonGroupService {
  static const String _baseUrl = 'http://127.0.0.1:8000'; // Python backend URL
  
  // For Android emulator, use: 'http://10.0.2.2:8000'
  // For iOS simulator, use: 'http://127.0.0.1:8000'  
  // For real device, use your computer's IP: 'http://192.168.1.XXX:8000'

  /// Get the current user's group information
  Future<Map<String, dynamic>?> getUserGroup(String userId) async {
    try {
      print('🔍 ===============================');
      print('🔍 GETTING USER GROUP FROM PYTHON BACKEND');
      print('🔍 ===============================');
      print('🔍 User ID: $userId');
      print('🔍 Python URL: $_baseUrl/groups/user/$userId/group');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/user/$userId/group'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Group data retrieved successfully');
        return responseData;
      } else {
        print('❌ Failed to get user group: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting user group: $e');
      return null;
    }
  }

  /// Get all group member IDs for the user's group
  Future<List<String>> getGroupMemberIds(String userId) async {
    try {
      print('🔍 Getting group member IDs for user: $userId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/user/$userId/members'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['group_found'] == true) {
          final memberIds = List<String>.from(responseData['member_ids'] ?? []);
          print('✅ Found ${memberIds.length} group member IDs: $memberIds');
          return memberIds;
        } else {
          print('⚠️ No group found for user: ${responseData['message']}');
          return [];
        }
      } else {
        print('❌ Failed to get group member IDs: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting group member IDs: $e');
      return [];
    }
  }

  /// UPDATED: Get group members with avatar data and real user details from Python backend
  Future<List<Map<String, dynamic>>> getGroupMembersWithAvatars(String userId) async {
    try {
      print('🔍 ===============================');
      print('🔍 GETTING GROUP MEMBERS WITH AVATARS AND REAL USER DETAILS');
      print('🔍 ===============================');
      print('🔍 User ID: $userId');
      print('🔍 Python URL: $_baseUrl/groups/user/$userId/members-with-avatars');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/user/$userId/members-with-avatars'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['group_found'] == true) {
          final List<dynamic> members = responseData['members'] ?? [];
          
          List<Map<String, dynamic>> processedMembers = [];
          
          for (var member in members) {
            final memberId = member['user_id'] ?? 'unknown';
            final firstname = member['firstname'] ?? 'Unknown';
            final lastname = member['lastname'] ?? 'User';
            final fullName = member['full_name'] ?? '$firstname $lastname';
            final hasAvatar = member['has_avatar'] == true;
            final avatarData = member['avatar_data'];
            
            // UPDATED: Create processed member object with real user details from Firebase
            processedMembers.add({
              'user_id': memberId,
              'firstname': firstname,  // Real firstname from Firebase
              'lastname': lastname,    // Real lastname from Firebase
              'full_name': fullName,   // Combined full name
              'email': '',             // Not fetched in this version
              'classe': responseData['class_name'] ?? '',
              'avatar_data': avatarData,
              'has_avatar': hasAvatar,
            });
            
            print('👤 Member processed: $memberId ($firstname $lastname) - Avatar: $hasAvatar');
          }
          
          print('✅ ===============================');
          print('✅ PROCESSED ${processedMembers.length} GROUP MEMBERS WITH REAL DETAILS');
          print('✅ Group: ${responseData['group_name']} (${responseData['class_name']})');
          print('✅ All members have real firstname and lastname from Firebase');
          print('✅ ===============================');
          
          // Debug print each member's details
          for (var member in processedMembers) {
            print('👥 Member: ${member['firstname']} ${member['lastname']} (ID: ${member['user_id']})');
          }
          
          return processedMembers;
        } else {
          print('⚠️ No group found for user: ${responseData['message']}');
          return [];
        }
      } else {
        print('❌ Failed to get group members with avatars: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting group members with avatars and real details: $e');
      return [];
    }
  }

  /// Debug method to check all groups
  Future<void> debugAllGroups() async {
    try {
      print('🔍 ===============================');
      print('🔍 DEBUG: ALL GROUPS FROM PYTHON BACKEND');
      print('🔍 ===============================');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/debug/all-groups'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📡 Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final groups = responseData['groups'] ?? [];
        
        print('📊 Total groups: ${responseData['total_groups']}');
        print('📊 ===============================');
        
        for (var group in groups) {
          print('🏢 Group: ${group['group_name']}');
          print('   - Class: ${group['class_name']}');
          print('   - Members: ${group['members']}');
          print('   - Count: ${group['member_count']}');
          print('   - Accessible: ${group['accessible']}');
          print('   ---');
        }
        
        print('📊 ===============================');
      } else {
        print('❌ Debug request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in debug request: $e');
    }
  }

  /// NEW: Debug method to check users collection structure
  Future<void> debugUsersStructure() async {
    try {
      print('🔍 ===============================');
      print('🔍 DEBUG: USERS COLLECTION STRUCTURE');
      print('🔍 ===============================');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/debug/users-structure'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📡 Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final users = responseData['users_structure'] ?? [];
        
        print('📊 Sample users found: ${responseData['total_sample_users']}');
        print('📊 ===============================');
        
        for (var user in users) {
          print('👤 Document ID: ${user['document_id']}');
          print('   - Available fields: ${user['available_fields']}');
          print('   - Sample data:');
          print('     * Firstname: ${user['sample_data']['firstname']}');
          print('     * Lastname: ${user['sample_data']['lastname']}');
          print('     * User ID: ${user['sample_data']['user_id']}');
          print('     * Email: ${user['sample_data']['email']}');
          print('   ---');
        }
        
        print('📊 ===============================');
      } else {
        print('❌ Debug users structure request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in debug users structure request: $e');
    }
  }

  /// Test connection to Python backend
  Future<bool> testConnection() async {
    try {
      print('🔗 Testing connection to Python backend...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 5));

      print('📡 Connection test - Status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }

  /// NEW: Enhanced debug method that checks both groups and user details
  Future<void> debugCompleteGroupUserFlow(String userId) async {
    try {
      print('🔍 ===============================');
      print('🔍 COMPLETE DEBUG: GROUP + USER DETAILS FLOW');
      print('🔍 ===============================');
      print('🔍 Testing user ID: $userId');
      
      // Test connection first
      final connectionOk = await testConnection();
      print('🔗 Connection test: ${connectionOk ? "PASSED" : "FAILED"}');
      
      if (!connectionOk) {
        print('❌ Aborting debug - no connection to backend');
        return;
      }
      
      // Debug users collection structure
      print('\n🔍 Step 1: Checking users collection structure...');
      await debugUsersStructure();
      
      // Debug all groups
      print('\n🔍 Step 2: Checking all groups...');
      await debugAllGroups();
      
      // Test getting specific user's group
      print('\n🔍 Step 3: Getting user\'s specific group...');
      final userGroup = await getUserGroup(userId);
      print('📊 User group result: $userGroup');
      
      // Test getting group members with details
      print('\n🔍 Step 4: Getting group members with full details...');
      final membersWithDetails = await getGroupMembersWithAvatars(userId);
      print('📊 Members with details count: ${membersWithDetails.length}');
      
      for (var member in membersWithDetails) {
        print('👥 Final result - ${member['firstname']} ${member['lastname']} (${member['user_id']}) - Avatar: ${member['has_avatar']}');
      }
      
      print('✅ ===============================');
      print('✅ COMPLETE DEBUG FLOW FINISHED');
      print('✅ ===============================');
      
    } catch (e) {
      print('❌ Error in complete debug flow: $e');
    }
  }


/// Get group accessibility status for current user
Future<bool> isGroupAccessible(String userId) async {
  try {
    print('🔍 Checking group accessibility for user: $userId');
    
    final response = await http.get(
      Uri.parse('$_baseUrl/groups/user/$userId/group'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      
      if (responseData['success'] == true && responseData['group_found'] == true) {
        final accessible = responseData['group']['accessible'] == true;
        print('✅ Group accessibility status: $accessible');
        return accessible;
      } else {
        print('⚠️ No group found for user, defaulting to not accessible');
        return false;
      }
    } else {
      print('❌ Failed to check group accessibility: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('❌ Error checking group accessibility: $e');
    return false;
  }
}


}