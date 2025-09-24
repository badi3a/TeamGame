import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';

class AvatarModel {
  String hairStyle;
  String hairColor;
  String eyeType;
  String mouthType;
  String clothes;
  String skinColor;
  String accessories;
  Color backgroundColor;
  
  // Timestamp for tracking creation/modification
  DateTime createdAt;
  DateTime updatedAt;
  
  AvatarModel({
    required this.hairStyle,
    required this.hairColor,
    required this.eyeType,
    required this.mouthType,
    required this.clothes,
    required this.skinColor,
    required this.accessories,
    required this.backgroundColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  // Static lists of available options
  static const List<String> hairStyles = [
    'No Hair',
    'Short Hair',
    'Long Hair',
    'Curly Hair', 
    'Bob Cut',
    'Mohawk',
    'Pixie Cut',
    'Wavy Hair',
    'Straight Hair',
    'Ponytail',
  ];
  
  static const List<String> hairColors = [
    'Black',
    'Brown',
    'Blonde',
    'Red',
    'Gray',
    'Auburn',
    'Platinum',
    'Chestnut',
    'Golden',
    'Silver',
  ];
  
  static const List<String> eyeTypes = [
    'Default',
    'Happy',
    'Surprised',
    'Wink',
    'Sleepy',
    'Heart',
    'Closed',
    'Squint',
    'Wide',
    'Serious',
  ];
  
  static const List<String> mouthTypes = [
    'Smile',
    'Neutral',
    'Sad',
    'Open',
    'Serious',
    'Tongue',
    'Laugh',
    'Smirk',
    'Frown',
    'Whistle',
  ];
  
  static const List<String> clothesTypes = [
    'T-Shirt',
    'Hoodie',
    'Blazer',
    'Sweater',
    'Tank Top',
    'Dress',
    'Polo',
    'Jacket',
    'Cardigan',
    'Vest',
  ];
  
  static const List<String> skinColors = [
    'Light',
    'Medium',
    'Dark',
    'Pale',
    'Tan',
    'Deep',
    'Olive',
    'Fair',
    'Warm',
    'Cool',
  ];
  
  static const List<String> accessoriesTypes = [
    'None',
    'Glasses',
    'Sunglasses',
    'Hat',
    'Cap',
    'Headband',
    'Earrings',
    'Necklace',
    'Scarf',
    'Bow Tie',
  ];

  static const List<Color> backgroundColors = [
    Color(0xFFFFEBEE), // Light Red
    Color(0xFFFFCDD2), // Light Red 2
    Color(0xFFEF9A9A), // Light Red 3
    Color(0xFFFFFFFF), // White
    Color(0xFFF5F5F5), // Light Gray
    Color(0xFFFCE4EC), // Light Pink
    Color(0xFFF3E5F5), // Light Purple
    Color(0xFFE8F5E8), // Light Green
    Color(0xFFE3F2FD), // Light Blue
    Color(0xFFFFF3E0), // Light Orange
  ];

  // Factory constructors
  factory AvatarModel.defaultAvatar() {
    return AvatarModel(
      hairStyle: 'Short Hair',
      hairColor: 'Brown',
      eyeType: 'Default',
      mouthType: 'Smile',
      clothes: 'T-Shirt',
      skinColor: 'Light',
      accessories: 'None',
      backgroundColor: backgroundColors[0],
    );
  }

  factory AvatarModel.randomAvatar() {
    final random = Random();
    return AvatarModel(
      hairStyle: hairStyles[random.nextInt(hairStyles.length)],
      hairColor: hairColors[random.nextInt(hairColors.length)],
      eyeType: eyeTypes[random.nextInt(eyeTypes.length)],
      mouthType: mouthTypes[random.nextInt(mouthTypes.length)],
      clothes: clothesTypes[random.nextInt(clothesTypes.length)],
      skinColor: skinColors[random.nextInt(skinColors.length)],
      accessories: accessoriesTypes[random.nextInt(accessoriesTypes.length)],
      backgroundColor: backgroundColors[random.nextInt(backgroundColors.length)],
    );
  }

  // Predefined avatar presets for quick selection
  factory AvatarModel.preset(String presetName) {
    switch (presetName.toLowerCase()) {
      case 'professional':
        return AvatarModel(
          hairStyle: 'Short Hair',
          hairColor: 'Brown',
          eyeType: 'Serious',
          mouthType: 'Neutral',
          clothes: 'Blazer',
          skinColor: 'Medium',
          accessories: 'Glasses',
          backgroundColor: backgroundColors[3], // White
        );
        
      case 'casual':
        return AvatarModel(
          hairStyle: 'Curly Hair',
          hairColor: 'Blonde',
          eyeType: 'Happy',
          mouthType: 'Smile',
          clothes: 'Hoodie',
          skinColor: 'Light',
          accessories: 'Cap',
          backgroundColor: backgroundColors[1], // Light Red 2
        );
        
      case 'creative':
        return AvatarModel(
          hairStyle: 'Long Hair',
          hairColor: 'Red',
          eyeType: 'Wide',
          mouthType: 'Laugh',
          clothes: 'Tank Top',
          skinColor: 'Tan',
          accessories: 'Headband',
          backgroundColor: backgroundColors[6], // Light Purple
        );
        
      case 'sporty':
        return AvatarModel(
          hairStyle: 'Ponytail',
          hairColor: 'Black',
          eyeType: 'Default',
          mouthType: 'Smirk',
          clothes: 'T-Shirt',
          skinColor: 'Dark',
          accessories: 'Cap',
          backgroundColor: backgroundColors[7], // Light Green
        );
        
      default:
        return AvatarModel.defaultAvatar();
    }
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'hairStyle': hairStyle,
      'hairColor': hairColor,
      'eyeType': eyeType,
      'mouthType': mouthType,
      'clothes': clothes,
      'skinColor': skinColor,
      'accessories': accessories,
      'backgroundColor': backgroundColor.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AvatarModel.fromJson(Map<String, dynamic> json) {
    return AvatarModel(
      hairStyle: json['hairStyle'] ?? 'Short Hair',
      hairColor: json['hairColor'] ?? 'Brown',
      eyeType: json['eyeType'] ?? 'Default',
      mouthType: json['mouthType'] ?? 'Smile',
      clothes: json['clothes'] ?? 'T-Shirt',
      skinColor: json['skinColor'] ?? 'Light',
      accessories: json['accessories'] ?? 'None',
      backgroundColor: Color(json['backgroundColor'] ?? backgroundColors[0].value),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    );
  }

  String toJsonString() => json.encode(toJson());
  
  static AvatarModel fromJsonString(String jsonString) {
    return AvatarModel.fromJson(json.decode(jsonString));
  }

  // Utility methods
  String generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = (hairStyle + hairColor + eyeType + mouthType).hashCode;
    return 'avatar_${timestamp}_${hash.abs()}';
  }

  AvatarModel copyWith({
    String? hairStyle,
    String? hairColor,
    String? eyeType,
    String? mouthType,
    String? clothes,
    String? skinColor,
    String? accessories,
    Color? backgroundColor,
  }) {
    return AvatarModel(
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      eyeType: eyeType ?? this.eyeType,
      mouthType: mouthType ?? this.mouthType,
      clothes: clothes ?? this.clothes,
      skinColor: skinColor ?? this.skinColor,
      accessories: accessories ?? this.accessories,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Validation methods
  bool isValid() {
    return hairStyles.contains(hairStyle) &&
           hairColors.contains(hairColor) &&
           eyeTypes.contains(eyeType) &&
           mouthTypes.contains(mouthType) &&
           clothesTypes.contains(clothes) &&
           skinColors.contains(skinColor) &&
           accessoriesTypes.contains(accessories);
  }

  List<String> getValidationErrors() {
    List<String> errors = [];
    
    if (!hairStyles.contains(hairStyle)) {
      errors.add('Invalid hair style: $hairStyle');
    }
    if (!hairColors.contains(hairColor)) {
      errors.add('Invalid hair color: $hairColor');
    }
    if (!eyeTypes.contains(eyeType)) {
      errors.add('Invalid eye type: $eyeType');
    }
    if (!mouthTypes.contains(mouthType)) {
      errors.add('Invalid mouth type: $mouthType');
    }
    if (!clothesTypes.contains(clothes)) {
      errors.add('Invalid clothes type: $clothes');
    }
    if (!skinColors.contains(skinColor)) {
      errors.add('Invalid skin color: $skinColor');
    }
    if (!accessoriesTypes.contains(accessories)) {
      errors.add('Invalid accessories: $accessories');
    }
    
    return errors;
  }

  // Static utility methods for color mapping
  static Color getHairColor(String colorName) {
    switch (colorName) {
      case 'Black':
        return const Color(0xFF2C1810);
      case 'Brown':
        return const Color(0xFF8B4513);
      case 'Blonde':
        return const Color(0xFFFFD700);
      case 'Red':
        return const Color(0xFFDC143C);
      case 'Gray':
        return const Color(0xFF808080);
      case 'Auburn':
        return const Color(0xFFA52A2A);
      case 'Platinum':
        return const Color(0xFFE5E4E2);
      case 'Chestnut':
        return const Color(0xFFCD853F);
      case 'Golden':
        return const Color(0xFFFFDF00);
      case 'Silver':
        return const Color(0xFFC0C0C0);
      default:
        return const Color(0xFF8B4513);
    }
  }

  static Color getSkinColor(String colorName) {
    switch (colorName) {
      case 'Light':
        return const Color(0xFFFFDFC4);
      case 'Medium':
        return const Color(0xFFF0D5BE);
      case 'Dark':
        return const Color(0xFFD08B5B);
      case 'Pale':
        return const Color(0xFFFFF2E8);
      case 'Tan':
        return const Color(0xFFE8B887);
      case 'Deep':
        return const Color(0xFF8D5524);
      case 'Olive':
        return const Color(0xFFBDB76B);
      case 'Fair':
        return const Color(0xFFFAE7D0);
      case 'Warm':
        return const Color(0xFFEFDBB2);
      case 'Cool':
        return const Color(0xFFF3E7DB);
      default:
        return const Color(0xFFFFDFC4);
    }
  }

  // Comparison and equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is AvatarModel &&
        other.hairStyle == hairStyle &&
        other.hairColor == hairColor &&
        other.eyeType == eyeType &&
        other.mouthType == mouthType &&
        other.clothes == clothes &&
        other.skinColor == skinColor &&
        other.accessories == accessories &&
        other.backgroundColor == backgroundColor;
  }

  @override
  int get hashCode {
    return Object.hash(
      hairStyle,
      hairColor,
      eyeType,
      mouthType,
      clothes,
      skinColor,
      accessories,
      backgroundColor,
    );
  }

  @override
  String toString() {
    return 'AvatarModel(hairStyle: $hairStyle, hairColor: $hairColor, '
           'eyeType: $eyeType, mouthType: $mouthType, clothes: $clothes, '
           'skinColor: $skinColor, accessories: $accessories, '
           'backgroundColor: $backgroundColor)';
  }

  // Convenience getters
  String get summary => '$hairColor $hairStyle with $eyeType eyes';
  
  bool get hasHair => hairStyle != 'No Hair';
  
  bool get hasAccessories => accessories != 'None';
  
  String get displayName => '${skinColor.split(' ')[0]} Avatar';
  
  // Style compatibility check
  bool isCompatibleWith(AvatarModel other) {
    // Simple compatibility logic - can be expanded
    return (skinColor == other.skinColor) ||
           (hairColor == other.hairColor) ||
           (clothes == other.clothes);
  }

  // Get a contrast color for text based on background
  Color get contrastColor {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Generate random variations of this avatar
  List<AvatarModel> generateVariations({int count = 3}) {
    final random = Random();
    final variations = <AvatarModel>[];
    
    for (int i = 0; i < count; i++) {
      variations.add(copyWith(
        hairColor: random.nextBool() ? null : hairColors[random.nextInt(hairColors.length)],
        eyeType: random.nextBool() ? null : eyeTypes[random.nextInt(eyeTypes.length)],
        mouthType: random.nextBool() ? null : mouthTypes[random.nextInt(mouthTypes.length)],
        accessories: random.nextBool() ? null : accessoriesTypes[random.nextInt(accessoriesTypes.length)],
        backgroundColor: random.nextBool() ? null : backgroundColors[random.nextInt(backgroundColors.length)],
      ));
    }
    
    return variations;
  }
}