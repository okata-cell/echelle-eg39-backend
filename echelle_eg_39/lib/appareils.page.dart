import 'package:flutter/material.dart';
import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'data_manager.dart';
import 'api_service.dart';
import 'appareil_images.dart';
import 'widgets/image_zoom_viewer.dart';

class AdminAppareilsPage extends StatefulWidget {
  const AdminAppareilsPage({super.key});

  @override
  State<AdminAppareilsPage> createState() => _AdminAppareilsPageState();
}

class _AdminAppareilsPageState extends State<AdminAppareilsPage> {
  final _dataManager = DataManager();
  bool _isLoadingAppareils = false;

  @override
  void initState() {
    super.initState();
    // Ne pas initialiser les appareils par défaut ici,
    // ils seront chargés depuis le backend ou utilisés comme fallback
    _loadAppareilsFromBackend();
  }

  Future<void> _loadAppareilsFromBackend() async {
    if (_isLoadingAppareils) return;
    setState(() => _isLoadingAppareils = true);
    try {
      final appareils = await ApiService.getAppareils();
      print('📡 Appareils reçus du backend: ${appareils.length}');
      for (final a in appareils) {
        print('  - ${a['code']}: ${a['nom']} | imageUrl: ${a['imageUrl']}');
      }
      if (mounted) {
        // Vider la liste actuelle et ajouter les appareils du backend
        _dataManager.clearAppareils();
        if (appareils.isNotEmpty) {
          for (final a in appareils) {
            _dataManager.addAppareil(Appareil(
              id: a['code'] as String? ?? 'APP-${a['id']}',
              dbId: a['id'] as int?,
              nom: a['nom'] as String,
              type: a['type'] as String,
              imageUrl: a['imageUrl'] as String? ??
                  AppareilImages.getImageUrlForAppareilId(
                    a['code'] as String? ?? '',
                  ),
              prixLocation: a['prixLocation'] as int,
              prixVente: a['prixVente'] as int,
              disponible: a['disponible'] as bool? ?? true,
            ));
          }
        } else {
          print('⚠️ Backend returned empty appareils list, loading defaults');
          _loadDefaultAppareils();
        }
      }
    } catch (e) {
      print('⚠️ Failed to load appareils from backend: $e');
      if (mounted) {
        _loadDefaultAppareils();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAppareils = false);
      }
    }
  }

  void _loadDefaultAppareils() {
    _dataManager.loadDefaultAppareils();
  }


  // URL d'image par défaut pour les types non définis
  final String defaultImageUrl = 'https://dodacvienthong.com/site/pictures/content/may-dinh-vi-ve-tinh-2-tan-so-gps-rtk-e-survey-e300-pro-imu.jpg';

  // Fonction pour obtenir l'URL d'image selon l'ID de l'appareil (prioritaire)
  String _getImageUrlForAppareilId(String appareilId) {
    return AppareilImages.getImageUrlForAppareilId(appareilId);
  }

  // Fonction pour obtenir l'URL d'image selon le type d'appareil
  String _getImageUrlForType(String type) {
    return AppareilImages.getImageUrlForType(type);
  }

  // Fonction de validation pour les champs numériques
  String? _validateNumericValue(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Le $fieldName est requis';
    }
    
    // Supprimer les espaces
    final cleanValue = value.trim();
    
    // Vérifier si c'est un nombre valide
    final numericRegex = RegExp(r'^[0-9]+$');
    if (!numericRegex.hasMatch(cleanValue)) {
      return 'Le $fieldName doit contenir uniquement des chiffres';
    }
    
    // Vérifier si la valeur est positive
    final number = int.tryParse(cleanValue);
    if (number == null) {
      return 'Le $fieldName n\'est pas valide';
    }
    
    if (number <= 0) {
      return 'Le $fieldName doit être supérieur à 0';
    }
    
    // Vérifier si la valeur n'est pas trop grande
    if (number > 999999999) {
      return 'Le $fieldName est trop élevé';
    }
    
    return null; // Validation réussie
  }

  // FORMULAIRE D'AJOUT D'APPAREIL
  void _ouvrirFormulaireAjout(BuildContext context) {
    final nomCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final prixLocCtrl = TextEditingController();
    final prixVenteCtrl = TextEditingController();
    final imageUrlCtrl = TextEditingController();
    
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Ajouter un appareil",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nom de l'appareil",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.devices),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom de l\'appareil est requis';
                      }
                      if (value.trim().length < 2) {
                        return 'Le nom doit contenir au moins 2 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: "Type (GPS, Niveau, Station Totale, Trepied, Mire...)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    onChanged: (value) {
                      // Actualiser la prévisualisation d'image quand le type change
                      setState(() {});
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le type d\'appareil est requis';
                      }
                      if (value.trim().length < 2) {
                        return 'Le type doit contenir au moins 2 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: imageUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: "URL de l'image (optionnel)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                      helperText: "Laissez vide pour utiliser l'image par défaut selon le type",
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  // Prévisualisation de l'image selon le type ou URL personnalisée
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: (typeCtrl.text.trim().isNotEmpty || imageUrlCtrl.text.trim().isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Image.network(
                                  imageUrlCtrl.text.trim().isNotEmpty
                                      ? imageUrlCtrl.text.trim()
                                      : _getImageUrlForType(typeCtrl.text.trim()),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_not_supported,
                                              size: 32,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Image non disponible',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Overlay avec le nom du type ou URL personnalisée
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      imageUrlCtrl.text.trim().isNotEmpty
                                          ? 'Image personnalisée'
                                          : 'Image pour: ${typeCtrl.text.trim()}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.preview,
                                  size: 32,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Prévisualisation de l\'image',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'L\'image sera automatiquement sélectionnée selon le type d\'appareil',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: prixLocCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Prix location / jour (FCFA)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                      helperText: "Veuillez saisir uniquement des chiffres",
                    ),
                    validator: (value) => _validateNumericValue(value, "prix de location"),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: prixVenteCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Prix de vente (FCFA)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sell),
                      helperText: "Veuillez saisir uniquement des chiffres",
                    ),
                    validator: (value) => _validateNumericValue(value, "prix de vente"),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Les prix doivent être exprimés en FCFA et ne contenir que des chiffres.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _ajouterAppareil(
                    nom: nomCtrl.text.trim(),
                    type: typeCtrl.text.trim(),
                    prixLoc: int.parse(prixLocCtrl.text.trim()),
                    prixVente: int.parse(prixVenteCtrl.text.trim()),
                    imageUrl: imageUrlCtrl.text.trim().isNotEmpty
                        ? imageUrlCtrl.text.trim()
                        : null,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Appareil ajouté avec succès!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }


  Future<void> _ajouterAppareil({
    required String nom,
    required String type,
    required int prixLoc,
    required int prixVente,
    String? imageUrl,
  }) async {
    try {
      // Envoyer à la base de données backend
      final result = await ApiService.createAppareil(
        nom: nom,
        type: type,
        prixLocation: prixLoc,
        prixVente: prixVente,
        imageUrl: imageUrl,
      );

      // Ajouter aussi localement pour l'affichage immédiat
      final createdAppareil = result['appareil'];
      _dataManager.addAppareil(
        Appareil(
          id: createdAppareil?['code'] ?? "APP-${DateTime.now().millisecondsSinceEpoch}",
          dbId: createdAppareil?['id'],
          nom: nom,
          type: type,
          imageUrl: imageUrl ?? _getImageUrlForType(type),
          prixLocation: prixLoc,
          prixVente: prixVente,
          disponible: true,
        ),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appareil ajouté avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Si l'API échoue, ajouter seulement localement
      _dataManager.addAppareil(
        Appareil(
          id: "APP-${DateTime.now().millisecondsSinceEpoch}",
          dbId: null, // Pas d'ID backend, sera assigné après sauvegarde
          nom: nom,
          type: type,
          imageUrl: imageUrl ?? _getImageUrlForType(type),
          prixLocation: prixLoc,
          prixVente: prixVente,
          disponible: true,
        ),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appareil ajouté (local): $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _ouvrirFormulaireModification(BuildContext context, int index) {
     final appareil = _dataManager.appareils[index];
     final nomCtrl = TextEditingController(text: appareil.nom);
     final typeCtrl = TextEditingController(text: appareil.type);
     final prixLocCtrl = TextEditingController(text: appareil.prixLocation.toString());
     final prixVenteCtrl = TextEditingController(text: appareil.prixVente.toString());
     final imageUrlCtrl = TextEditingController(text: appareil.imageUrl);
     
     final formKey = GlobalKey<FormState>();

     showDialog(
       context: context,
       builder: (context) {
         return AlertDialog(
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(16),
           ),
           title: const Text(
             "Modifier l'appareil",
             style: TextStyle(
               fontWeight: FontWeight.bold,
               color: Color(0xFF1E293B),
             ),
           ),
           content: SingleChildScrollView(
             child: Form(
               key: formKey,
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   TextFormField(
                     controller: nomCtrl,
                     decoration: const InputDecoration(
                       labelText: "Nom de l'appareil",
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.devices),
                     ),
                     validator: (value) {
                       if (value == null || value.trim().isEmpty) {
                         return 'Le nom de l\'appareil est requis';
                       }
                       if (value.trim().length < 2) {
                         return 'Le nom doit contenir au moins 2 caractères';
                       }
                       return null;
                     },
                   ),
                   const SizedBox(height: 16),
                   TextFormField(
                     controller: typeCtrl,
                     decoration: const InputDecoration(
                       labelText: "Type",
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.category),
                     ),
                     validator: (value) {
                       if (value == null || value.trim().isEmpty) {
                         return 'Le type d\'appareil est requis';
                       }
                       return null;
                     },
                   ),
                   const SizedBox(height: 16),
                   TextFormField(
                     controller: imageUrlCtrl,
                     decoration: const InputDecoration(
                       labelText: "URL image",
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.image),
                       hintText: "https://...jpg",
                     ),
                     keyboardType: TextInputType.url,
                   ),
                   const SizedBox(height: 16),
                   TextFormField(
                     controller: prixLocCtrl,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(
                       labelText: "Prix location / jour (FCFA)",
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.access_time),
                     ),
                     validator: (value) => _validateNumericValue(value, "prix de location"),
                   ),
                   const SizedBox(height: 16),
                   TextFormField(
                     controller: prixVenteCtrl,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(
                       labelText: "Prix de vente (FCFA)",
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.sell),
                     ),
                     validator: (value) => _validateNumericValue(value, "prix de vente"),
                   ),
                 ],
               ),
             ),
           ),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: const Text("Annuler"),
             ),
             ElevatedButton(
               onPressed: () {
                 if (formKey.currentState!.validate()) {
                   _modifierAppareil(
                     index: index,
                     nom: nomCtrl.text.trim(),
                     type: typeCtrl.text.trim(),
                     prixLoc: int.parse(prixLocCtrl.text.trim()),
                     prixVente: int.parse(prixVenteCtrl.text.trim()),
                     imageUrl: imageUrlCtrl.text.trim(),
                   );
                   Navigator.pop(context);
                 }
               },
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.blue.shade600,
                 foregroundColor: Colors.white,
               ),
               child: const Text("Enregistrer"),
             ),
           ],
         );
       },
     );
   }

    Future<void> _modifierAppareil({
      required int index,
      required String nom,
      required String type,
      required int prixLoc,
      required int prixVente,
      required String imageUrl,
    }) async {
      try {
        final appareil = _dataManager.appareils[index];
        // Utiliser dbId (ID de la base de données) au lieu d'extraire l'ID du code
        final id = appareil.dbId ?? 0;
        final result = await ApiService.updateAppareil(
          id: id,
          nom: nom,
          type: type,
          prixLocation: prixLoc,
          prixVente: prixVente,
          imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
        );
       
        _dataManager.updateAppareil(
          index,
          Appareil(
            id: appareil.id,
            dbId: appareil.dbId,
            nom: nom,
            type: type,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : appareil.imageUrl,
            prixLocation: prixLoc,
            prixVente: prixVente,
            disponible: appareil.disponible,
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appareil modifié avec succès!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        final appareil = _dataManager.appareils[index];
        _dataManager.updateAppareil(
          index,
          Appareil(
            id: appareil.id,
            dbId: appareil.dbId,
            nom: nom,
            type: type,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : appareil.imageUrl,
            prixLocation: prixLoc,
            prixVente: prixVente,
            disponible: appareil.disponible,
          ),
        );
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Appareil modifié (local): $e'),
             backgroundColor: Colors.orange,
           ),
         );
       }
     }
   }

  void changerStatut(int index) {
    _dataManager.toggleDisponibilite(index);
  }

  void supprimerAppareil(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirmer la suppression',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer l\'appareil "${_dataManager.appareils[index].nom}" ?',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final appareil = _dataManager.appareils[index];
                // Supprimer aussi sur le backend
                if (appareil.dbId != null) {
                  try {
                    await ApiService.deleteAppareil(appareil.dbId!);
                  } catch (e) {
                    print('⚠️ Erreur suppression backend: $e');
                  }
                }
                _dataManager.removeAppareil(index);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Appareil supprimé avec succès',
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminPageHeader(
          title: 'Appareils',
          subtitle: 'Gérez le parc matériel, les tarifs et la disponibilité.',
          icon: Icons.gps_fixed,
          actions: [
            IconButton(
              onPressed: () => _ouvrirFormulaireAjout(context),
              tooltip: 'Ajouter un appareil',
              icon: const Icon(Icons.add_circle_outline),
              color: AdminPalette.blueprintBlue,
            ),
            IconButton(
              onPressed: _loadAppareilsFromBackend,
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh),
              color: AdminPalette.blueprintBlue,
            ),
          ],
        ),
        Expanded(
          child: _isLoadingAppareils
              ? const AdminLoadingState(label: 'Chargement du parc matériel…')
              : _dataManager.appareils.isEmpty
                  ? const AdminEmptyState(
                      icon: Icons.devices_other_outlined,
                      title: 'Aucun appareil enregistré',
                      message: 'Ajoutez un appareil pour alimenter le catalogue.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          itemCount: _dataManager.appareils.length,
          itemBuilder: (context, index) {
            final a = _dataManager.appareils[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE SECTION WITH OVERLAY
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                          child: ZoomableImage(
                            imageUrl: a.imageUrl,
                            fallbackUrl: AppareilImages.getImageUrlForType(a.type),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            title: a.nom,
                          ),
                        ),
                        // Gradient overlay (ignore pointer to allow tap on image)
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: true,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20)),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // ID Badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              a.id,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // CONTENT SECTION
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Appareil name
                          Text(
                            a.nom,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Type with icon
                          Row(
                            children: [
                              Icon(
                                _getTypeIcon(a.type),
                                size: 18,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Type : ${a.type}",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Pricing section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade50,
                                  Colors.indigo.shade50,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildPriceItem(
                                  "Location",
                                  "${a.prixLocation.toString()} FCFA",
                                  Icons.access_time,
                                  Colors.orange,
                                ),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Colors.grey.shade300,
                                ),
                                _buildPriceItem(
                                  "Vente",
                                  "${a.prixVente.toString()} FCFA",
                                  Icons.sell,
                                  Colors.green,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Status and actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Status chip with enhanced design
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: a.disponible
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: a.disponible
                                        ? Colors.green.shade300
                                        : Colors.red.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      a.disponible
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 16,
                                      color: a.disponible
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      a.disponible
                                          ? "Disponible"
                                          : "Indisponible",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: a.disponible
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Enhanced popup menu
                              PopupMenuButton<String>(
                                 icon: Icon(
                                   Icons.more_vert,
                                   color: Colors.grey.shade600,
                                 ),
                                 shape: RoundedRectangleBorder(
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                                 onSelected: (value) {
                                   if (value == "edit") {
                                     _ouvrirFormulaireModification(context, index);
                                   } else if (value == "statut") {
                                     changerStatut(index);
                                   } else if (value == "delete") {
                                     supprimerAppareil(index);
                                   }
                                 },
                                 itemBuilder: (context) => [
                                   PopupMenuItem(
                                     value: "edit",
                                     child: Row(
                                       children: [
                                         Icon(
                                           Icons.edit,
                                           color: Colors.blue.shade600,
                                         ),
                                         const SizedBox(width: 12),
                                         const Text("Modifier"),
                                       ],
                                     ),
                                   ),
                                   PopupMenuItem(
                                     value: "statut",
                                     child: Row(
                                       children: [
                                         Icon(
                                           Icons.toggle_on,
                                           color: Colors.blue.shade600,
                                         ),
                                         const SizedBox(width: 12),
                                         const Text("Changer disponibilité"),
                                       ],
                                     ),
                                   ),
                                   PopupMenuItem(
                                     value: "delete",
                                     child: Row(
                                       children: [
                                         Icon(
                                           Icons.delete,
                                           color: Colors.red.shade600,
                                         ),
                                         const SizedBox(width: 12),
                                         const Text("Supprimer"),
                                       ],
                                     ),
                                   ),
                                 ],
                               ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
                    },
                  ),
        ),
      ],
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'gps':
        return Icons.gps_fixed;
      case 'niveau':
        return Icons.straighten;
      case 'station totale':
      case 'theodolite':
        return Icons.engineering;
      case 'trepied':
        return Icons.adjust;
      case 'mire':
        return Icons.straighten;
      default:
        return Icons.devices;
    }
  }

  Widget _buildPriceItem(String label, String price, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          price,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
