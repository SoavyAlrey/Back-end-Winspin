// lib/widgets/wheel_painter.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui; // Import pour ui.Image

import '../models/prize.dart';

class WheelPainter extends CustomPainter {
  final List<Prize> prizes;
  final double rotationAngle;
  // AJOUT: Cache d'images reçu depuis l'écran parent
  final Map<String, ui.Image> images;

  WheelPainter({
    required this.prizes,
    this.rotationAngle = 0.0,
    required this.images, // Requis maintenant
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = min(size.width / 2, size.height / 2) * 0.95; // Un peu plus grand
    // ... (Styles de peinture inchangés: borderPaint, segmentPaint) ...
    final Paint borderPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Paint segmentPaint = Paint()..style = PaintingStyle.fill;


    final List<Prize> drawablePrizes = prizes.where((p) => p.canBeWon).toList();
    if (drawablePrizes.isEmpty) {
      // ... (Gestion aucun lot inchangée) ...
      segmentPaint.color = Colors.grey;
      canvas.drawCircle(center, radius, segmentPaint);
      canvas.drawCircle(center, radius, borderPaint);
      TextPainter textPainter = TextPainter( /* ... */ ); // Dessine "Aucun lot"
      textPainter.layout(minWidth: 0, maxWidth: size.width * 0.6);
      textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
      return;
    }

    double totalProbability = drawablePrizes.fold(0.0, (sum, item) => sum + item.probability);
    if (totalProbability <= 0) {
      // Si proba = 0, utilise des parts égales pour le dessin
      totalProbability = drawablePrizes.length.toDouble();
    }


    double startAngle = -pi / 2 + rotationAngle;

    for (int i = 0; i < drawablePrizes.length; i++) {
      final Prize prize = drawablePrizes[i];
      // Utilise 1 si proba totale était 0, sinon la vraie probabilité
      final double currentProb = (totalProbability == drawablePrizes.length.toDouble()) ? 1.0 : prize.probability;
      final double sweepAngle = (currentProb / totalProbability) * 2 * pi;

      segmentPaint.color = prize.color;
      canvas.drawArc(/* ... */ Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, true, segmentPaint);
      canvas.drawArc(/* ... */ Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, true, borderPaint);

      // --- Dessiner Image OU Texte ---
      final double midAngle = startAngle + sweepAngle / 2;
      // Récupère l'image chargée depuis le cache
      final ui.Image? prizeImage = (prize.imageUrl != null) ? images[prize.imageUrl!] : null;

      // Sauvegarde l'état du canvas avant rotation/translation pour le texte/image
      canvas.save();

      // Calcule la position de base (par exemple, à 65% du rayon)
      final double contentRadius = radius * 0.65;
      final Offset contentOffset = Offset(
        center.dx + contentRadius * cos(midAngle),
        center.dy + contentRadius * sin(midAngle),
      );
      // Déplace l'origine du canvas vers la position du contenu
      canvas.translate(contentOffset.dx, contentOffset.dy);
      // Rotation pour aligner avec le rayon
      canvas.rotate(midAngle + pi / 2); // +90 degrés pour que le contenu soit radial

      if (prizeImage != null) {
        // --- Dessiner l'Image ---
        // Détermine la taille max de l'image (ex: 40% du rayon, ou basé sur taille segment)
        final double maxImageSize = radius * 0.4;
        // Calcule les dimensions pour garder le ratio de l'image
        final double imgRatio = prizeImage.width / prizeImage.height;
        double imgWidth = maxImageSize;
        double imgHeight = imgWidth / imgRatio;
        if (imgHeight > maxImageSize) {
          imgHeight = maxImageSize;
          imgWidth = imgHeight * imgRatio;
        }

        // Rectangle source (toute l'image)
        final Rect srcRect = Rect.fromLTWH(0, 0, prizeImage.width.toDouble(), prizeImage.height.toDouble());
        // Rectangle destination (centré à l'origine translatée/rotatée)
        final Rect dstRect = Rect.fromCenter(center: Offset.zero, width: imgWidth, height: imgHeight);

        // Dessine l'image
        canvas.drawImageRect(prizeImage, srcRect, dstRect, Paint());

        // Optionnel: Dessiner le nom sous l'image
        _drawText(canvas, prize.name, Offset(0, imgHeight / 2 + 5), radius * 0.5, segmentPaint.color);

      } else {
        // --- Dessiner le Texte (si pas d'image) ---
        _drawText(canvas, prize.name, Offset.zero, radius * 0.5, segmentPaint.color);
      }

      // Restaure l'état précédent du canvas (annule translate/rotate)
      canvas.restore();

      startAngle += sweepAngle;
    }

    canvas.drawCircle(center, radius, borderPaint); // Cercle extérieur
  }


  /// Fonction helper pour dessiner le texte (maintenant réutilisable)
  void _drawText(Canvas canvas, String text, Offset position, double maxWidth, Color segmentColor) {
    final textStyle = TextStyle(
        color: _getIdealTextColor(segmentColor),
        fontSize: 12, // Ajuster si besoin
        fontWeight: FontWeight.bold,
        shadows: const [ // Ombre légère pour la lisibilité
          Shadow(blurRadius: 1.0, color: Colors.black54, offset: Offset(1,1))
        ]
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    // Mise en page avec largeur max pour gérer les textes longs
    textPainter.layout(minWidth: 0, maxWidth: maxWidth);

    // Dessine le texte centré sur la 'position' donnée (qui est déjà à l'origine translatée/rotatée)
    textPainter.paint(canvas, position - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  Color _getIdealTextColor(Color backgroundColor) {
    // ... (Fonction inchangée) ...
    double luminance = (0.299 * backgroundColor.red + 0.587 * backgroundColor.green + 0.114 * backgroundColor.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }


  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) {
    // Redessiner si les lots, la rotation OU le cache d'images changent.
    return oldDelegate.prizes != prizes ||
        oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.images != images;
  }
}