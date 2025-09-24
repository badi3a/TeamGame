import 'package:flutter/material.dart';

enum IslandStatus {
  locked,
  available,
  completed,
}

class QuizIsland {
  final int id;
  final String name;
  final Offset position;
  final double size;
  final Color color;
  final IconData icon;
  final String quizTopic;
  final String description;
  final String difficulty;
  final String? imagePath;
  final String? blackWhiteImagePath; // Added for black and white version
  final double rotationSpeed;
  final double floatAmplitude;
  final IslandStatus status;
  final bool isUnlocked;
  final double? categoryScore;
  final String? categoryId;

  QuizIsland({
    required this.id,
    required this.name,
    required this.position,
    required this.size,
    required this.color,
    required this.icon,
    required this.quizTopic,
    required this.description,
    required this.difficulty,
    this.imagePath,
    this.blackWhiteImagePath, // Added to constructor
    this.rotationSpeed = 1.0,
    this.floatAmplitude = 10.0,
    this.status = IslandStatus.locked,
    this.isUnlocked = false,
    this.categoryScore,
    this.categoryId,
  });

  // Helper method to check if island can be tapped
  bool get canBeTapped => status == IslandStatus.available;

  // Get icon based on status
  IconData getStatusIcon() {
    switch (status) {
      case IslandStatus.locked:
        return Icons.lock;
      case IslandStatus.available:
        return icon;
      case IslandStatus.completed:
        return Icons.check_circle;
    }
  }

  // Get color based on status
  Color getStatusColor() {
    switch (status) {
      case IslandStatus.locked:
        return Colors.grey.shade600;
      case IslandStatus.available:
        return color;
      case IslandStatus.completed:
        return Colors.green.shade600;
    }
  }

  // Get score display text
  String get scoreDisplayText {
    if (categoryScore == null) return '';
    return '${categoryScore!.toStringAsFixed(1)}/5';
  }

  // CopyWith method for creating modified copies
  QuizIsland copyWith({
    int? id,
    String? name,
    Offset? position,
    double? size,
    Color? color,
    IconData? icon,
    String? quizTopic,
    String? description,
    String? difficulty,
    String? imagePath,
    String? blackWhiteImagePath, // Added to copyWith
    double? rotationSpeed,
    double? floatAmplitude,
    IslandStatus? status,
    bool? isUnlocked,
    double? categoryScore,
    String? categoryId,
  }) {
    return QuizIsland(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      size: size ?? this.size,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      quizTopic: quizTopic ?? this.quizTopic,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      imagePath: imagePath ?? this.imagePath,
      blackWhiteImagePath: blackWhiteImagePath ?? this.blackWhiteImagePath, // Added to copyWith
      rotationSpeed: rotationSpeed ?? this.rotationSpeed,
      floatAmplitude: floatAmplitude ?? this.floatAmplitude,
      status: status ?? this.status,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      categoryScore: categoryScore ?? this.categoryScore,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}