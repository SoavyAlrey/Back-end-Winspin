// lib/models/prize.dart
import 'package:flutter/material.dart';

/// Represents a prize item displayed on the wheel.
/// Corresponds to the 'Produit' entity possibly augmented with 'Lot' data (color).
class Prize {
  final int id;           // Corresponds to Produit.id_produit
  final String name;        // Corresponds to Produit.nom_produit
  late final double probability; // Corresponds to Produit.probabilite
  final Color color;         // Corresponds potentially to Lot.couleur_roue
  final int stock;          // Corresponds to Produit.quantite_stock
  final String? imageUrl;   // Corresponds to Produit.image

  Prize({
    required this.id,
    required this.name,
    required this.probability,
    required this.color,
    required this.stock,
    this.imageUrl,
  });

  /// Creates a Prize instance from a JSON map (typically from API response).
  factory Prize.fromJson(Map<String, dynamic> json) {
    String colorString = json['couleur_roue'] ?? '#CCCCCC'; // Default grey if null
    int currentStock = (json['quantite_stock'] as num? ?? 0).toInt();

    return Prize(
      id: (json['id_produit'] ?? json['id'] as num? ?? 0).toInt(),
      name: json['nom_produit'] ?? json['name'] ?? 'N/A',
      probability: (json['probabilite'] as num? ?? 0.0).toDouble(),
      // Use the utility function for robust color parsing
      color: hexToColor(colorString, defaultColor: '#CCCCCC'),
      stock: currentStock,
      imageUrl: json['image'],
    );
  }

  /// Converts this Prize instance into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id_produit': id,
      'nom_produit': name,
      'probabilite': probability,
      // Ensure color is always in #RRGGBB format
      'couleur_roue': '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      'quantite_stock': stock,
      'image': imageUrl,
    };
  }

  /// Indicates if the prize is out of stock.
  bool get isOutOfStock => stock <= 0;

  /// Indicates if the prize has a valid probability to be won.
  /// (Assuming probability > 0 means it can be won)
  bool get canBeWon => probability > 0 && !isOutOfStock;

}

/// Utility function to convert Hex color string (e.g., #FF0000 or FF0000) to Color object.
/// Provides a fallback default color if parsing fails or format is incorrect.
Color hexToColor(String hexString, {String defaultColor = '#CCCCCC'}) {
  hexString = hexString.toUpperCase().replaceAll("#", "");
  if (hexString.length == 6) {
    hexString = "FF$hexString"; // Add alpha if missing (assume fully opaque)
  }
  if (hexString.length == 8) {
    try {
      return Color(int.parse("0x$hexString"));
    } catch (e) {
      // Fallback to default color in case of parsing error
      print("Error parsing color $hexString: $e"); // Log error for debugging
      return hexToColor(defaultColor.replaceAll("#", ""), defaultColor: '#CCCCCC');
    }
  }
  // Fallback if length is wrong
  print("Incorrect color hex length for $hexString"); // Log error for debugging
  return hexToColor(defaultColor.replaceAll("#", ""), defaultColor: '#CCCCCC');
}