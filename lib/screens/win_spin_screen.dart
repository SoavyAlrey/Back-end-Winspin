// lib/screens/win_spin_screen.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui; // Import pour ui.Image
import 'package:flutter/services.dart'; // Pour rootBundle (chargement image) - Optionnel
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart'; // AJOUT: Pour les sons

import '../models/prize.dart';
import '../widgets/wheel_painter.dart';

class WinSpinScreen extends StatefulWidget {
  const WinSpinScreen({super.key});

  @override
  State<WinSpinScreen> createState() => _WinSpinScreenState();
}

class _WinSpinScreenState extends State<WinSpinScreen> with SingleTickerProviderStateMixin {
  // ... (Variables existantes: prizes, animation, controllers de texte, etc.) ...
  List<Prize> prizes = [];

  late final AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  double _currentRotation = 0.0;
  double _targetRotation = 0.0;
  Prize? _selectedPrize;
  bool _isSpinning = false;
  final Random _random = Random();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _probabilityController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  int? _editingPrizeIndex;

  // AJOUT: Cache pour les images chargées (URL -> ui.Image)
  final Map<String, ui.Image> _prizeImages = {};
  bool _areImagesLoading = false; // Indicateur de chargement

  // AJOUT: Lecteur audio
  final AudioPlayer _audioPlayer = AudioPlayer();


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addStatusListener(_handleAnimationStatus);

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    // Charge les lots ET les images associées
    _loadPrizesAndImages();

    // Préparer le lecteur audio (optionnel)
    // _audioPlayer.setReleaseMode(ReleaseMode.stop); // Arrête le son précédent si un nouveau est joué
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _probabilityController.dispose();
    _stockController.dispose();
    _imageUrlController.dispose();
    _colorController.dispose();
    _audioPlayer.dispose(); // AJOUT: Libère les ressources audio
    // AJOUT: Nettoyer les images du cache (si nécessaire)
    _prizeImages.clear();
    super.dispose();
  }

  // --- Gestion des Données et Images ---

  /// Charge les lots depuis SharedPreferences PUIS charge les images associées.
  Future<void> _loadPrizesAndImages() async {
    await _loadPrizes(); // Attend la fin du chargement des lots
    await _loadPrizeImages(); // Charge ensuite les images pour les lots actuels
  }

  Future<void> _loadPrizes() async {
    // ... (Code _loadPrizes inchangé) ...
    final prefs = await SharedPreferences.getInstance();
    final String? prizesJson = prefs.getString('winspinPrizes');
    List<Prize> loadedPrizes = [];

    if (prizesJson != null) {
      try {
        final List<dynamic> decodedJson = jsonDecode(prizesJson) as List;
        loadedPrizes = decodedJson.map((jsonItem) => Prize.fromJson(jsonItem as Map<String, dynamic>)).toList();
        print("Lots chargés depuis SharedPreferences.");
      } catch (e) {
        print("Erreur lors du décodage des lots depuis SharedPreferences: $e");
        loadedPrizes = _getDefaultPrizesList(); // Utilise les lots par défaut en cas d'erreur
      }
    } else {
      print("Aucun lot sauvegardé trouvé, chargement des lots par défaut.");
      loadedPrizes = _getDefaultPrizesList(); // Utilise les lots par défaut
    }
    // Met à jour l'état seulement après avoir potentiellement chargé les images
    if (mounted) { // Vérifie si le widget est toujours dans l'arbre
      setState(() {
        prizes = loadedPrizes;
      });
    }

  }

  /// Charge de manière asynchrone les images pour les lots actuels.
  Future<void> _loadPrizeImages() async {
    if (!mounted) return; // Ne rien faire si le widget n'est plus là
    setState(() { _areImagesLoading = true; });

    int loadedCount = 0;
    List<String> urlsToLoad = prizes
        .where((p) => p.imageUrl != null && p.imageUrl!.isNotEmpty && !_prizeImages.containsKey(p.imageUrl))
        .map((p) => p.imageUrl!)
        .toList();

    if (urlsToLoad.isEmpty) {
      if (mounted) setState(() { _areImagesLoading = false; });
      print("Aucune nouvelle image à charger.");
      return;
    }

    print("Chargement de ${urlsToLoad.length} images...");

    for (String url in urlsToLoad) {
      try {
        final image = await _loadImage(url);
        if (image != null && mounted) {
          // Vérifie à nouveau si l'URL n'a pas été ajoutée entre temps
          if (!_prizeImages.containsKey(url)) {
            setState(() {
              _prizeImages[url] = image;
            });
            loadedCount++;
          }
        }
      } catch (e) {
        print("Erreur chargement image $url: $e");
        // Optionnel: ajouter une image placeholder en cas d'erreur ?
        // if (mounted && !_prizeImages.containsKey(url)) {
        //   // setState(() { _prizeImages[url] = _placeholderImage; }); // Nécessite de charger _placeholderImage
        // }
      }
    }

    if (mounted) {
      setState(() { _areImagesLoading = false; });
    }
    print("Chargement terminé. $loadedCount nouvelles images ajoutées au cache.");
    // Force un redessin si des images ont été chargées
    if (loadedCount > 0 && mounted) setState(() {});
  }

  /// Fonction helper pour charger une seule image depuis une URL.
  Future<ui.Image?> _loadImage(String url) async {
    try {
      // Utilise NetworkImage pour bénéficier du cache Flutter
      final ImageStream stream = NetworkImage(url).resolve(ImageConfiguration.empty);
      final completer = Completer<ui.Image>();
      late ImageStreamListener listener;

      listener = ImageStreamListener(
            (ImageInfo imageInfo, bool synchronousCall) {
          completer.complete(imageInfo.image);
          stream.removeListener(listener); // Nettoie l'écouteur
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          completer.completeError(exception, stackTrace);
          stream.removeListener(listener);
        },
      );

      stream.addListener(listener);
      return await completer.future;
    } catch (e) {
      print("Exception dans _loadImage pour $url: $e");
      return null;
    }
  }


  Future<void> _savePrizes() async {
    // ... (Code _savePrizes inchangé) ...
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> prizesJsonList = prizes.map((p) => p.toJson()).toList();
    final String encodedJson = jsonEncode(prizesJsonList);
    await prefs.setString('winspinPrizes', encodedJson);
    print("Lots sauvegardés dans SharedPreferences.");
    // Recharger les images si la liste a changé (nouvelles URLs)
    await _loadPrizeImages();
  }

  List<Prize> _getDefaultPrizesList() {
    // Retourne juste la liste, ne modifie pas l'état ici
    return [
      Prize(id: 1, name: 'Coca Cola', probability: 25.0, color: hexToColor('#F40009'), stock: 10, imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ce/Coca-Cola_logo.svg/2560px-Coca-Cola_logo.svg.png'), // Exemple URL
      Prize(id: 2, name: 'Sprite', probability: 25.0, color: hexToColor('#008B47'), stock: 10, imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bf/Sprite_Logo.svg/1200px-Sprite_Logo.svg.png'), // Exemple URL
      Prize(id: 3, name: 'Fanta', probability: 20.0, color: hexToColor('#FF8300'), stock: 5), // Sans image
      Prize(id: 4, name: 'Pepsi', probability: 15.0, color: hexToColor('#0052A0'), stock: 1, imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Pepsi_logo_2014.svg/1200px-Pepsi_logo_2014.svg.png'), // Exemple URL
      Prize(id: 5, name: 'Blu 250ml', probability: 10.0, color: hexToColor('#007AC0'), stock: 0),
      Prize(id: 6, name: 'Perdu', probability: 5.0, color: hexToColor('#5A5A5A'), stock: 999),
    ];
  }

  void _setDefaultPrizes() {
    if (mounted) {
      setState(() {
        prizes = _getDefaultPrizesList();
      });
      // _savePrizes(); // Sauvegarde immédiate si besoin
    }
  }


  // --- Logique d'Animation et Son ---
  void _startSpin() async { // AJOUT: async pour await sur le son
    if (_isSpinning) return;

    final drawablePrizes = prizes.where((p) => p.canBeWon).toList();
    if (drawablePrizes.isEmpty) {
      // ... (gestion aucun lot) ...
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun lot disponible pour tourner la roue ! Ajoutez ou modifiez des lots.")),
      );
      return;
    }


    // AJOUT: Jouer le son de rotation au début
    try {
      await _audioPlayer.play(AssetSource('audio/spin_sound.mp3')); // Utilise le nom de ton fichier
      print("Playing spin sound");
    } catch (e) {
      print("Erreur lors de la lecture du son de spin: $e");
    }

    // ... (Reste du code _startSpin inchangé) ...
    final int spins = _random.nextInt(4) + 3;
    final double randomOffset = _random.nextDouble() * 2 * pi;
    _targetRotation = _currentRotation + spins * 2 * pi + randomOffset;

    _rotationAnimation = Tween<double>(
      begin: _currentRotation,
      end: _targetRotation,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCirc),
    );

    _animationController
      ..reset()
      ..forward();
  }

  void _handleAnimationStatus(AnimationStatus status) async { // AJOUT: async pour await sur le son
    if (status == AnimationStatus.forward) {
      // ... (code inchangé) ...
      setState(() {
        _isSpinning = true;
        _selectedPrize = null;
      });
    } else if (status == AnimationStatus.completed) {
      // Arrêter le son de spin s'il est encore en cours (optionnel)
      // await _audioPlayer.stop();

      final Prize? winner = _getPrizeFromAngle(_targetRotation % (2 * pi), pointerAngle: pi / 2);

      // AJOUT: Jouer le son de victoire SI on a gagné un vrai lot
      if (winner != null && winner.name != 'Perdu') { // Ne pas jouer si 'Perdu' ou erreur
        try {
          await _audioPlayer.play(AssetSource('audio/win_sound.mp3')); // Utilise le nom de ton fichier
          print("Playing win sound");
        } catch (e) {
          print("Erreur lors de la lecture du son de victoire: $e");
        }
      }

      setState(() {
        _isSpinning = false;
        _currentRotation = _targetRotation % (2 * pi);
        _selectedPrize = winner;
        // ... (Gestion du stock commentée comme avant) ...
      });
    }
  }

  Prize? _getPrizeFromAngle(double finalAngle, {required double pointerAngle}) {
    // ... (Code _getPrizeFromAngle inchangé) ...
    // (il utilise déjà la liste `prizes` à jour)
    final drawable = prizes.where((p) => p.canBeWon).toList();
    if (drawable.isEmpty) return null;

    final double totalProb = drawable.fold(0.0, (sum, p) => sum + p.probability);
    if (totalProb <= 0) {
      // Si somme proba = 0 mais lots drawable existent, attribuer proba égale pour le tirage
      final double equalSweep = (2 * pi) / drawable.length;
      double adjusted = (pointerAngle - finalAngle) % (2 * pi);
      double cumulative = 0.0;
      const double startOffset = -pi / 2;

      for (final prize in drawable) {
        final double segStart = (startOffset + cumulative) % (2 * pi);
        final double segEnd = (segStart + equalSweep) % (2 * pi);
        bool inside = (segStart <= segEnd)
            ? (adjusted >= segStart && adjusted < segEnd)
            : (adjusted >= segStart || adjusted < segEnd);
        if (inside) return prize;
        cumulative += equalSweep;
      }
      return null; // Ne devrait pas arriver

    }

    double adjusted = (pointerAngle - finalAngle) % (2 * pi);
    double cumulative = 0.0;
    const double startOffset = -pi / 2;

    for (final prize in drawable) {
      final double sweep = (prize.probability / totalProb) * 2 * pi;
      final double segStart = (startOffset + cumulative) % (2 * pi);
      final double segEnd = (segStart + sweep) % (2 * pi);

      bool inside = (segStart <= segEnd)
          ? (adjusted >= segStart && adjusted < segEnd)
          : (adjusted >= segStart || adjusted < segEnd);

      if (inside) return prize;
      cumulative += sweep;
    }
    print("Avertissement: Aucun lot trouvé pour l'angle ajusté $adjusted (final: $finalAngle).");
    return null; // Sécurité
  }

  // --- Construction de l'UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( /* ... AppBar inchangée ... */
        title: const Text('WinSpin SalesUpLift'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Sauvegarder la configuration',
            onPressed: _savePrizes,
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Roue et Pointeur ---
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: WheelPainter(
                            prizes: prizes,
                            rotationAngle: _rotationAnimation.value,
                            // AJOUT: Passer le cache d'images au painter
                            images: _prizeImages,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned( /* ... Votre pointeur Icon ... */
                    bottom: 0,
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      size: 48,
                      color: Colors.red.shade800,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 5.0)],
                    ),
                  ),
                  // AJOUT: Indicateur de chargement des images (optionnel)
                  if (_areImagesLoading)
                    Container(
                      width: 300, height: 300,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle
                      ),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white,)),
                    )
                ],
              ),
              const SizedBox(height: 40),
              // --- Bouton Tourner ---
              ElevatedButton.icon( /* ... Votre bouton ... */
                icon: const Icon(Icons.sync),
                label: const Text('Bismillah !', style: TextStyle(fontSize: 20)),
                onPressed: _isSpinning ? null : _startSpin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
              const SizedBox(height: 30),
              // --- Affichage Résultat ---
              Text( /* ... Votre Text résultat ... */
                _isSpinning
                    ? 'Bonne chance...'
                    : (_selectedPrize != null
                    ? 'Résultat : ${_selectedPrize!.name} !'
                    : 'Prêt à tourner ?'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _selectedPrize?.color ?? Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // --- Section de Configuration ---
              _buildConfigurationSection(), // Inchangé
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets et Méthodes pour la Configuration ---
  Widget _buildConfigurationSection() { /* ... Code inchangé ... */
    return ExpansionTile(
      title: const Text('Gestion des Lots', style: TextStyle(fontWeight: FontWeight.bold)),
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPrizeForm(),
              const SizedBox(height: 20),
              const Divider(),
              const Text("Liste des Lots Actuels", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _buildPrizeList(), // Ce widget utilise maintenant les images chargées
              const SizedBox(height: 10),
              const Divider(),
              Wrap(
                spacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Recharger'),
                    onPressed: _loadPrizesAndImages, // Recharge lots ET images
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  ),
                ],
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPrizeForm() { /* ... Code inchangé ... */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_editingPrizeIndex == null ? "Ajouter un Nouveau Lot" : "Modifier le Lot", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom du Lot', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: TextField(controller: _probabilityController, decoration: const InputDecoration(labelText: 'Probabilité (%)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _stockController, decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(controller: _imageUrlController, decoration: const InputDecoration(labelText: 'URL Image (Optionnel)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _colorController, decoration: const InputDecoration(labelText: 'Couleur Hex (ex: #FF0000)', border: OutlineInputBorder())),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          icon: Icon(_editingPrizeIndex == null ? Icons.add : Icons.check),
          label: Text(_editingPrizeIndex == null ? 'Ajouter le Lot' : 'Mettre à Jour'),
          onPressed: _addOrUpdatePrize,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
        ),
        if (_editingPrizeIndex != null) ...[
          const SizedBox(height: 5),
          TextButton(
            child: const Text('Annuler la modification'),
            onPressed: _cancelEdit,
          )
        ]
      ],
    );
  }

  Widget _buildPrizeList() { /* ... Code légèrement modifié pour utiliser le cache d'images ... */
    if (prizes.isEmpty) {
      return const Text("Aucun lot configuré.", textAlign: TextAlign.center);
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prizes.length,
      itemBuilder: (context, index) {
        final prize = prizes[index];
        // Récupère l'image depuis le cache si elle existe
        final ui.Image? prizeImage = (prize.imageUrl != null) ? _prizeImages[prize.imageUrl!] : null;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: prize.color,
              // Afficher l'image (si chargée) ou l'initiale
              backgroundImage: (prizeImage != null)
                  ? _UiImageProvider(prizeImage) // Utilise un ImageProvider custom
                  : null, // Pas de backgroundImage si pas d'image chargée
              child: (prizeImage == null) // Affiche l'initiale seulement si pas d'image
                  ? Text(prize.name.isNotEmpty ? prize.name.substring(0,1).toUpperCase() : "?", style: const TextStyle(color: Colors.white))
                  : null, // Pas de texte si l'image est là
            ),
            title: Text(prize.name),
            subtitle: Text('Prob: ${prize.probability.toStringAsFixed(1)}% - Stock: ${prize.stock}'),
            trailing: Row( /* ... Row inchangée avec boutons Edit/Delete ... */
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Modifier',
                  onPressed: () => _editPrize(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: () => _deletePrize(index),
                ),
              ],
            ),
            enabled: prize.canBeWon,
          ),
        );
      },
    );
  }

  void _addOrUpdatePrize() { /* ... Modifié pour appeler _loadPrizeImages après ajout/modif ... */
    // ... (Validation comme avant) ...
    final String name = _nameController.text.trim();
    final double? probability = double.tryParse(_probabilityController.text.trim());
    final int? stock = int.tryParse(_stockController.text.trim());
    final String imageUrl = _imageUrlController.text.trim();
    final String colorHex = _colorController.text.trim();

    if (name.isEmpty || probability == null || stock == null || probability < 0 || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir correctement Nom, Probabilité (>=0) et Stock (>=0).')),
      );
      return;
    }
    Color prizeColor = hexToColor(colorHex);
    final newId = _editingPrizeIndex == null ? DateTime.now().millisecondsSinceEpoch : prizes[_editingPrizeIndex!].id;
    final newPrize = Prize(
      id: newId,
      name: name,
      probability: probability,
      color: prizeColor,
      stock: stock,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
    );

    bool needsImageLoad = false;
    setState(() {
      if (_editingPrizeIndex == null) {
        prizes.add(newPrize);
        if (newPrize.imageUrl != null && !_prizeImages.containsKey(newPrize.imageUrl)) {
          needsImageLoad = true;
        }
      } else {
        // Vérifie si l'URL a changé avant de mettre à jour
        if (prizes[_editingPrizeIndex!].imageUrl != newPrize.imageUrl && newPrize.imageUrl != null && !_prizeImages.containsKey(newPrize.imageUrl)) {
          needsImageLoad = true;
        }
        prizes[_editingPrizeIndex!] = newPrize;
        _editingPrizeIndex = null;
      }
      _clearForm();
    });

    // Sauvegarde et recharge les images si nécessaire
    _savePrizes().then((_) {
      if (needsImageLoad) {
        _loadPrizeImages(); // Lance le chargement si une nouvelle URL a été ajoutée/modifiée
      }
    });
    FocusScope.of(context).unfocus();
  }
  void _editPrize(int index) { /* ... Code inchangé ... */
    setState(() {
      _editingPrizeIndex = index;
      final prize = prizes[index];
      _nameController.text = prize.name;
      _probabilityController.text = prize.probability.toString();
      _stockController.text = prize.stock.toString();
      _imageUrlController.text = prize.imageUrl ?? '';
      _colorController.text = '#${prize.color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    });
  }
  void _cancelEdit() { /* ... Code inchangé ... */
    setState(() {
      _editingPrizeIndex = null;
      _clearForm();
    });
    FocusScope.of(context).unfocus();
  }
  void _deletePrize(int index) { /* ... Code inchangé ... */
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirmer la Suppression'),
          content: Text('Voulez-vous vraiment supprimer le lot "${prizes[index].name}" ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onPressed: () {
                final removedPrize = prizes.removeAt(index);
                // Optionnel : supprimer l'image du cache si elle n'est plus utilisée par d'autres lots
                if (removedPrize.imageUrl != null && !prizes.any((p) => p.imageUrl == removedPrize.imageUrl)) {
                  _prizeImages.remove(removedPrize.imageUrl);
                }
                setState(() {}); // Met à jour l'UI
                _savePrizes(); // Sauvegarde après suppression
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }
  void _clearForm() { /* ... Code inchangé ... */
    _nameController.clear();
    _probabilityController.clear();
    _stockController.clear();
    _imageUrlController.clear();
    _colorController.clear();
  }

} // Fin de _WinSpinScreenState


// AJOUT: Un ImageProvider personnalisé pour utiliser un ui.Image déjà chargé
class _UiImageProvider extends ImageProvider<Object> {
  final ui.Image image;

  _UiImageProvider(this.image);

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) {
    // Clé simple basée sur l'objet image lui-même
    return SynchronousFuture<Object>(image);
  }

  @override
  ImageStreamCompleter loadBuffer(Object key, DecoderBufferCallback decode) {
    // Comme l'image est déjà décodée (ui.Image), on la retourne directement.
    return OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: image)));
  }
}


// --- Utilitaire HexToColor ---
Color hexToColor(String hexString, {String defaultColor = '#CCCCCC'}) {
  // ... (Code hexToColor inchangé) ...
  String hex = hexString.toUpperCase().replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  if (hex.length == 8) {
    try {
      return Color(int.parse('0x$hex'));
    } catch (e) {
      print("Erreur parsing couleur '$hexString': $e");
      return hexToColor(defaultColor);
    }
  }
  print("Longueur hex couleur incorrecte: '$hexString'");
  return hexToColor(defaultColor);
}