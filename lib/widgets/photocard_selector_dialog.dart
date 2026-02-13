import 'package:flutter/material.dart';
import 'package:k_photo/data_storage_service.dart';
import 'package:k_photo/models/profile_wall.dart';

class PhotocardSelectorDialog extends StatefulWidget {
  final DataStorageService dataStorageService;
  final Function(String instanceId, String imagePath) onPhotocardSelected;
  final List<ProfileWallSlot> currentWallSlots; // Adicionado parâmetro para slots atuais

  const PhotocardSelectorDialog({
    Key? key,
    required this.dataStorageService,
    required this.onPhotocardSelected,
    required this.currentWallSlots, // Parâmetro obrigatório
  }) : super(key: key);

  @override
  State<PhotocardSelectorDialog> createState() => _PhotocardSelectorDialogState();
}

class _PhotocardSelectorDialogState extends State<PhotocardSelectorDialog> {
  List<Map<String, dynamic>> _photocards = [];
  List<ProfileWallSlot> _wallSlots = []; // Para controlar photocards no mural
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPhotocards();
    _loadWallSlots(); // Carrega os slots do mural
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega os dados sempre que o diálogo é reconstruído
    _loadWallSlots();
    _loadPhotocards();
  }

  Future<void> _loadWallSlots() async {
    // Usa os slots atuais passados como parâmetro em vez de buscar do banco
    if (mounted) {
      setState(() {
        _wallSlots = widget.currentWallSlots;
      });
      debugPrint('🔄 Slots do mural carregados do estado local: ${_wallSlots.length} slots');
      for (final slot in _wallSlots) {
        if (!slot.isEmpty) {
          debugPrint('  - Slot ${slot.position}: ${slot.photocardInstanceId}');
        }
      }
    }
  }

  Future<void> _loadPhotocards() async {
    setState(() => _isLoading = true);
    try {
      final photocards = await widget.dataStorageService.getAllUserPhotocards();
      setState(() {
        _photocards = photocards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar photocards: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPhotocards {
    if (_searchQuery.isEmpty) {
      // Filtra photocards que já estão no mural
      final wallInstanceIds = _wallSlots
          .where((slot) => !slot.isEmpty)
          .map((slot) => slot.photocardInstanceId!)
          .toSet();
      
      return _photocards.where((card) {
        final instanceId = card['instance_id'] as String;
        return !wallInstanceIds.contains(instanceId);
      }).toList();
    }
    
    // Filtra photocards que já estão no mural e aplica busca
    final wallInstanceIds = _wallSlots
        .where((slot) => !slot.isEmpty)
        .map((slot) => slot.photocardInstanceId!)
        .toSet();
    
    return _photocards.where((card) {
      final instanceId = card['instance_id'] as String;
      final imagePath = card['image_path'].toString().toLowerCase();
      final location = card['location'].toString().toLowerCase();
      
      // Não mostra se já está no mural
      if (wallInstanceIds.contains(instanceId)) {
        return false;
      }
      
      return imagePath.contains(_searchQuery.toLowerCase()) ||
             location.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String _getCardLocation(Map<String, dynamic> card) {
    final location = card['location'] as String;
    switch (location) {
      case 'backpack':
        return 'Mochila';
      case 'shared_pile':
        return 'Monte Compartilhado';
      case 'binder':
        final binderId = card['binder_id'] as String?;
        final slotIndex = card['slot_index'] as int?;
        final pageNumber = card['page_number'] as int?;
        return 'Binder ${binderId?.substring(0, 8) ?? ''} - Página $pageNumber, Slot $slotIndex';
      default:
        return location;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selecione um Photocard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink[700],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search bar
            
            // Photocards list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPhotocards.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum photocard encontrado',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: _filteredPhotocards.length,
                          itemBuilder: (context, index) {
                            final card = _filteredPhotocards[index];
                            final instanceId = card['instance_id'] as String;
                            
                            // Verifica se este photocard já está no mural
                            final isInWall = _wallSlots.any((slot) => 
                                !slot.isEmpty && slot.photocardInstanceId == instanceId);
                            
                            return GestureDetector(
                              onTap: isInWall ? null : () {
                                widget.onPhotocardSelected(card['instance_id'], card['image_path']);
                                Navigator.pop(context);
                              },
                              child: _buildPhotocardCard(card),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotocardCard(Map<String, dynamic> card) {
    final imagePath = card['image_path'] as String;
    final location = card['location'] as String;
    final instanceId = card['instance_id'] as String;
    
    // Verifica se este photocard já está no mural
    final isInWall = _wallSlots.any((slot) => 
        !slot.isEmpty && slot.photocardInstanceId == instanceId);
  
    return Stack(
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Indicador visual se já está no mural
        if (isInWall)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wallpaper,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No Mural',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
