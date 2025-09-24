// services/simple_group_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class SimpleGroupService {
  static const String _pythonBaseUrl = 'http://127.0.0.1:8000'; // Your Python backend URL
  
  /// Get group members for a user (just the names as strings)
  Future<List<String>> getUserGroupMembers(String firstName, String lastName) async {
    try {
      print('🔍 ===============================');
      print('🔍 GETTING GROUP MEMBERS (SIMPLE)');
      print('🔍 ===============================');
      print('🔍 User: "$firstName" "$lastName"');
      
      // Clean and validate input
      final cleanFirstName = firstName.trim();
      final cleanLastName = lastName.trim();
      
      if (cleanFirstName.isEmpty || cleanLastName.isEmpty) {
        print('❌ First name or last name is empty');
        return [];
      }
      
      // Construct full name with single space
      final userFullName = '$cleanFirstName $cleanLastName';
      print('🔍 Searching for full name: "$userFullName"');
      
      // Try direct API call first (more efficient)
      final directResult = await _getUserGroupMembersDirect(cleanFirstName, cleanLastName);
      if (directResult.isNotEmpty) {
        return directResult;
      }
      
      // Fallback to local search through all groups
      print('⚠️ Direct API call failed, trying local search...');
      final fallbackResult = await _getUserGroupMembersLocal(userFullName);
      return fallbackResult;
      
    } catch (e, stackTrace) {
      print('❌ Error getting group members: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Direct API call to find user's group members
  Future<List<String>> _getUserGroupMembersDirect(String firstName, String lastName) async {
    try {
      final url = '$_pythonBaseUrl/api/groups/user/$firstName/$lastName/group-members';
      print('🔗 Direct API URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));
      
      print('📡 Direct API Response Status: ${response.statusCode}');
      print('📡 Direct API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['group_found'] == true) {
          final List<dynamic> members = responseData['members'] ?? [];
          final memberNames = members
              .map((m) => m.toString().trim())
              .where((name) => name.isNotEmpty)
              .toList();
          
          print('✅ Direct API success: Found ${memberNames.length} members');
          print('👥 Members: $memberNames');
          return memberNames;
        } else {
          print('⚠️ Direct API: Group not found for user');
          return [];
        }
      } else {
        print('⚠️ Direct API failed with status: ${response.statusCode}');
        return [];
      }
      
    } catch (e) {
      print('❌ Error in direct API call: $e');
      return [];
    }
  }
  
  /// Local search through all groups (fallback)
  Future<List<String>> _getUserGroupMembersLocal(String userFullName) async {
    try {
      print('🔍 Starting local search for: "$userFullName"');
      
      // Get all groups from Python backend
      final allGroups = await _getAllGroups();
      if (allGroups.isEmpty) {
        print('⚠️ No groups found in database');
        return [];
      }
      
      print('📋 Total groups loaded: ${allGroups.length}');
      
      // Search for the user in all groups locally
      for (int i = 0; i < allGroups.length; i++) {
        final group = allGroups[i];
        final members = group['members'] as List<dynamic>? ?? [];
        final groupName = group['group_name'] ?? 'Unknown Group';
        
        print('🔍 Checking group ${i + 1}/"$groupName" with ${members.length} members');
        print('📝 Members in group: $members');
        
        // Check if user is in this group with multiple matching strategies
        for (final member in members) {
          final memberStr = member.toString().trim();
          
          // Strategy 1: Exact match (case-insensitive)
          if (memberStr.toLowerCase() == userFullName.toLowerCase()) {
            print('✅ EXACT MATCH: Found "$userFullName" in group "$groupName"');
            return _extractMemberNames(members);
          }
          
          // Strategy 2: Normalized whitespace match
          final normalizedMember = _normalizeWhitespace(memberStr);
          final normalizedUser = _normalizeWhitespace(userFullName);
          if (normalizedMember.toLowerCase() == normalizedUser.toLowerCase()) {
            print('✅ NORMALIZED MATCH: Found "$userFullName" in group "$groupName"');
            return _extractMemberNames(members);
          }
          
          // Strategy 3: Contains match (less strict)
          if (memberStr.toLowerCase().contains(userFullName.toLowerCase())) {
            print('✅ CONTAINS MATCH: Found "$userFullName" in group "$groupName"');
            print('📝 Matched member string: "$memberStr"');
            return _extractMemberNames(members);
          }
        }
      }
      
      print('❌ User "$userFullName" not found in any group after thorough search');
      return [];
      
    } catch (e) {
      print('❌ Error in local group search: $e');
      return [];
    }
  }
  
  /// Extract and clean member names from members list
  List<String> _extractMemberNames(List<dynamic> members) {
    final memberNames = members
        .map((m) => m.toString().trim())
        .where((name) => name.isNotEmpty)
        .toSet() // Remove duplicates
        .toList();
    
    print('👥 Extracted ${memberNames.length} unique members: $memberNames');
    return memberNames;
  }
  
  /// Normalize whitespace in strings (remove extra spaces, tabs, etc.)
  String _normalizeWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  
  /// Get all groups from Python backend
  Future<List<Map<String, dynamic>>> _getAllGroups() async {
    try {
      // Try the debug endpoint first
      var url = '$_pythonBaseUrl/api/groups/debug/all-groups';
      print('🔗 Python API URL (debug): $url');
      
      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));
      
      print('📡 Python API Response Status (debug): ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> groups = responseData['groups'] ?? [];
        print('✅ Successfully retrieved ${groups.length} groups from debug endpoint');
        return groups.cast<Map<String, dynamic>>();
      }
      
      // If debug endpoint fails, try regular groups endpoint
      print('⚠️ Debug endpoint failed, trying regular endpoint...');
      url = '$_pythonBaseUrl/api/groups/';
      print('🔗 Python API URL (regular): $url');
      
      response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));
      
      print('📡 Python API Response Status (regular): ${response.statusCode}');
      print('📡 Python API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> groups = json.decode(response.body);
        print('✅ Successfully retrieved ${groups.length} groups from regular endpoint');
        
        // Convert to the expected format
        return groups.map((group) => {
          'group_id': group['idGroup'],
          'group_name': group['groupName'] ?? 'Unknown Group',
          'members': group['members'] ?? [],
          'member_count': (group['members'] as List?)?.length ?? 0,
        }).toList().cast<Map<String, dynamic>>();
      } else {
        print('⚠️ Regular API returned status: ${response.statusCode}');
        print('⚠️ Response body: ${response.body}');
        return [];
      }
      
    } catch (e) {
      print('❌ Error calling Python API: $e');
      return [];
    }
  }
  
  /// Debug method to test the service with enhanced logging
  Future<void> debugGroupSearch(String firstName, String lastName) async {
    try {
      print('🔍 ===============================');
      print('🔍 DEBUG: ENHANCED GROUP SEARCH');
      print('🔍 ===============================');
      
      final cleanFirstName = firstName.trim();
      final cleanLastName = lastName.trim();
      final userFullName = '$cleanFirstName $cleanLastName';
      
      print('🔍 Input: firstName="$firstName", lastName="$lastName"');
      print('🔍 Cleaned: firstName="$cleanFirstName", lastName="$cleanLastName"');
      print('🔍 Full name to search: "$userFullName"');
      
      final allGroups = await _getAllGroups();
      print('📋 Searching for "$userFullName" in ${allGroups.length} groups');
      
      for (int i = 0; i < allGroups.length; i++) {
        final group = allGroups[i];
        final members = group['members'] as List<dynamic>? ?? [];
        final groupName = group['group_name'] ?? 'Unknown Group';
        
        print('');
        print('🔍 Group ${i + 1}: "$groupName" (${members.length} members)');
        print('📝 Raw members: $members');
        
        for (int j = 0; j < members.length; j++) {
          final member = members[j];
          final memberStr = member.toString().trim();
          
          print('  👤 Member ${j + 1}: "$memberStr"');
          print('    - Length: ${memberStr.length}');
          print('    - Exact match: ${memberStr.toLowerCase() == userFullName.toLowerCase()}');
          print('    - Contains: ${memberStr.toLowerCase().contains(userFullName.toLowerCase())}');
          print('    - Normalized: "${_normalizeWhitespace(memberStr)}"');
          
          if (memberStr.toLowerCase() == userFullName.toLowerCase()) {
            print('✅ ✅ ✅ FOUND! User "$userFullName" is in group "$groupName"');
            print('👥 All members in this group: $members');
            return;
          }
        }
      }
      
      print('');
      print('❌ User "$userFullName" not found in any group');
      
    } catch (e) {
      print('❌ Error in debug search: $e');
    }
  }
}