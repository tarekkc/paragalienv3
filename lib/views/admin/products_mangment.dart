import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:typed_data';
import 'package:paragalien/views/admin/promotions_management_screen.dart';
import 'package:paragalien/models/produit.dart';

class ProductsManagementScreen extends ConsumerStatefulWidget {
  const ProductsManagementScreen({super.key});

  @override
  ConsumerState<ProductsManagementScreen> createState() =>
      _ProductsManagementScreenState();
}

class _ProductsManagementScreenState
    extends ConsumerState<ProductsManagementScreen> {
  final _searchController = TextEditingController();
  List<Produit> _allProduits = [];
  List<Produit> _filteredProduits = [];
  bool _isLoading = true;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadProduits();
    _searchController.addListener(_filterProduits);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProduits() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('produits')
          .select('*')
          .order('name');

      setState(() {
        _allProduits = response.map((p) => Produit.fromJson(p)).toList();
        _filteredProduits = List.from(_allProduits);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Erreur de chargement: ${e.toString()}');
    }
  }

  void _filterProduits() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProduits = _allProduits.where((produit) {
        return produit.name.toLowerCase().contains(query) ||
            produit.price.toString().contains(query) ||
            produit.quantity.toString().contains(query);
      }).toList();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des Produits'),
          actions: [
            IconButton(
              icon: const Icon(Icons.local_offer),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PromotionsManagementScreen(),
                  ),
                );
              },
              tooltip: 'Voir les promotions',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showEditProductDialog(context),
              tooltip: 'Ajouter un produit',
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _filterProduits();
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProduits.isEmpty
                      ? Center(
                          child: _searchController.text.isEmpty
                              ? const Text('Aucun produit trouvé')
                              : const Text('Aucun résultat pour cette recherche'),
                        )
                      : ListView.builder(
                          itemCount: _filteredProduits.length,
                          itemBuilder: (context, index) {
                            final produit = _filteredProduits[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: produit.imageUrl != null
                                    ? Image.network(
                                        produit.imageUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.shopping_bag),
                                title: Text(produit.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Prix: ${produit.price} DZD'),
                                    Text('Stock: ${produit.quantity}'),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditProductDialog(context, produit);
                                    } else if (value == 'delete') {
                                      _showDeleteConfirmation(context, produit);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) {
                                    return [
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Modifier'),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text(
                                          'Supprimer',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ];
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProductDialog(BuildContext context, [Produit? produit]) async {
    final nameController = TextEditingController(text: produit?.name ?? '');
    final priceController = TextEditingController(
      text: produit?.price.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: produit?.quantity.toString() ?? '',
    );
    String? imagePath;
    Uint8List? imageBytes;
    bool isUploading = false;
    String? selectedCategory =
        produit?.category?.isNotEmpty == true ? produit!.category : null;
    bool shouldDeleteImage = false;

    const List<String> categories = [
      'Complément alimentaire',
      'matériale médicale',
      'antiseptique',
      'dermo cosmetique',
      'Article bébé',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              produit == null ? 'Ajouter un produit' : 'Modifier produit',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUploading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(),
                    )
                  else if (imageBytes != null ||
                      (produit?.imageUrl != null && !shouldDeleteImage))
                    Column(
                      children: [
                        Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: imageBytes != null
                              ? Image.memory(
                                  imageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : produit?.imageUrl != null
                                  ? Image.network(
                                      produit!.imageUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer image'),
                                content: const Text(
                                  'Voulez-vous vraiment supprimer cette image?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text(
                                      'Supprimer',
                                      style: TextStyle(
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              setState(() {
                                imageBytes = null;
                                imagePath = null;
                                shouldDeleteImage = true;
                              });
                            }
                          },
                          child: const Text(
                            'Supprimer image',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: const Text('Choisir une image'),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowMultiple: false,
                        allowedExtensions: ['jpg', 'jpeg', 'png'],
                      );

                      if (result != null && result.files.single.path != null) {
                        final file = File(result.files.single.path!);
                        final bytes = await file.readAsBytes();

                        if (bytes.length > 5 * 1024 * 1024) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'L\'image ne doit pas dépasser 5MB',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() {
                          imagePath = result.files.single.path!;
                          imageBytes = bytes;
                          shouldDeleteImage = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: categories.contains(selectedCategory)
                        ? selectedCategory
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie*',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('catégorie'),
                      ),
                      ...categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }),
                    ],
                    validator: (value) =>
                        value == null ? 'Ce champ est obligatoire' : null,
                    onChanged: (value) {
                      setState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du produit*',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ce champ est obligatoire';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Prix (DZD)*',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ce champ est obligatoire';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Entrez un nombre valide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantité en stock*',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ce champ est obligatoire';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Entrez un nombre valide';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        // Validate form
                        if (nameController.text.isEmpty ||
                            priceController.text.isEmpty ||
                            quantityController.text.isEmpty ||
                            selectedCategory == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Veuillez remplir tous les champs obligatoires',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() => isUploading = true);
                        String? imageUrl;

                        try {
                          // Handle image deletion if marked for deletion
                          if (shouldDeleteImage && produit?.imageUrl != null) {
                            try {
                              final oldFileName =
                                  produit!.imageUrl!.split('/').last;
                              await Supabase.instance.client.storage
                                  .from('paragalien.photos')
                                  .remove([oldFileName]);
                            } catch (e) {
                              debugPrint('Error deleting old image: $e');
                            }
                          }

                          // Upload new image if selected
                          if (imageBytes != null) {
                            if (produit?.imageUrl != null && !shouldDeleteImage) {
                              try {
                                final oldFileName =
                                    produit!.imageUrl!.split('/').last;
                                await Supabase.instance.client.storage
                                    .from('paragalien.photos')
                                    .remove([oldFileName]);
                              } catch (e) {
                                debugPrint('Error deleting old image: $e');
                              }
                            }

                            final fileName =
                                '${DateTime.now().millisecondsSinceEpoch}${path.extension(imagePath!)}';

                            await Supabase.instance.client.storage
                                .from('paragalien.photos')
                                .uploadBinary(fileName, imageBytes!);

                            imageUrl = Supabase.instance.client.storage
                                .from('paragalien.photos')
                                .getPublicUrl(fileName);
                          }

                          // Prepare product data
                          final newProduit = {
                            'name': nameController.text.trim(),
                            'Price': double.tryParse(priceController.text) ?? 0,
                            'Stock ( Unité )': double.tryParse(
                                  quantityController.text,
                                ) ??
                                0,
                            'image_url': shouldDeleteImage
                                ? null
                                : (imageUrl ?? produit?.imageUrl),
                            'category': selectedCategory,
                            'updated_at': DateTime.now().toIso8601String(),
                          };

                          if (produit == null) {
                            await Supabase.instance.client
                                .from('produits')
                                .insert(newProduit);
                          } else {
                            await Supabase.instance.client
                                .from('produits')
                                .update(newProduit)
                                .eq('id', produit.id);
                          }

                          Navigator.pop(context, true);
                        } catch (e) {
                          debugPrint('Error saving product: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() => isUploading = false);
                        }
                      },
                child: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      await _loadProduits();
      _showSnackBar(
        produit == null ? 'Produit ajouté avec succès' : 'Produit mis à jour',
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, Produit produit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Supprimer ${produit.name}? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await Supabase.instance.client
                    .from('produits')
                    .delete()
                    .eq('id', produit.id);

                Navigator.pop(context);
                await _loadProduits();
                _showSnackBar('Produit supprimé avec succès');
              } catch (e) {
                Navigator.pop(context);
                _showSnackBar('Erreur: ${e.toString()}', isError: true);
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}