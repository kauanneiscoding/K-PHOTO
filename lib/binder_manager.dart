import '../data_storage_service.dart';
import 'dart:convert';

class Page {
  final int pageNumber;
  final int numberOfSlots;
  List<String?> slots; // Lista de slots (photocards)

  Page({
    required this.pageNumber,
    required this.numberOfSlots,
    required this.slots,
  });

  void addPhotocard(int index, String? photocard) {
    if (index >= 0 && index < slots.length) {
      slots[index] = photocard;
    }
  }

  void removePhotocard(int index) {
    if (index >= 0 && index < slots.length) {
      slots[index] = null;
    }
  }

  String? getPhotocard(int index) {
    if (index >= 0 && index < slots.length) {
      return slots[index];
    }
    return null;
  }

  List<String> get nonNullSlots =>
      slots.where((slot) => slot != null).map((slot) => slot!).toList();
}

class Binder {
  final String id;
  final List<Page> pages;
  final String coverAsset;
  final String name;

  Binder({
    required this.id,
    required this.pages,
    required this.coverAsset,
    required this.name,
  });
}

class BinderManager {
  final DataStorageService _dataStorageService = DataStorageService();
  final List<Binder> binders = [];
  final List<String> sharedPile = []; // Monte compartilhado de photocards

  Future<void> addBinder(String id) async {
    try {
      List<String?> slots = List.generate(9, (_) => null);
      List<Page> pages = [
        Page(
          pageNumber: 0,
          numberOfSlots: 9,
          slots: slots,
        ),
      ];

      await _dataStorageService.addBinder(
        id,
        pages.expand((page) => page.nonNullSlots).join(','),
      );

      binders.add(Binder(
        id: id,
        pages: pages,
        coverAsset: '',
        name: 'Novo Binder',
      ));

      print('Binder adicionado: $id');
    } catch (e) {
      print('Erro ao adicionar binder: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllBinders() async {
    try {
      return await _dataStorageService.getAllBinders();
    } catch (e) {
      print('Erro ao carregar binders: $e');
      return [];
    }
  }

  Future<void> updateBinderSlots(String binderId, List<String> slots) async {
    try {
      List<Map<String, dynamic>> slotsData = slots
          .map((slot) => {
                'image_path': slot,
              })
          .toList();

      await _dataStorageService.updateBinderSlots(binderId, slotsData);
      print('Slots do binder atualizados: $binderId');
    } catch (e) {
      print('Erro ao atualizar slots do binder: $e');
    }
  }

  Future<void> loadBinders() async {
    binders.clear();
    try {
      final binderMaps = await _dataStorageService.getAllBinders();
      for (var binderMap in binderMaps) {
        String id = binderMap['id'] as String;
        List<String?> slots = [];

        if (binderMap['slots'] != null) {
          final slotsData = jsonDecode(binderMap['slots'] as String);
          slots = List<String?>.from(
            (slotsData as List).map((slot) => slot['image_path'] as String?),
          );
        }

        if (slots.isEmpty) {
          slots = List.generate(9, (_) => null);
        }

        binders.add(Binder(
          id: id,
          pages: [
            Page(pageNumber: 0, numberOfSlots: 9, slots: slots),
          ],
          coverAsset: '',
          name: 'Nome do Binder',
        ));
      }

      if (binders.isEmpty) {
        String defaultId = DateTime.now().millisecondsSinceEpoch.toString();
        await addBinder(defaultId);
      }

      print('Binders carregados: ${binders.length}');
    } catch (e) {
      print('Erro ao carregar binders: $e');
    }
  }

  Future<Binder> getBinder(String id) async {
    return binders.firstWhere(
      (binder) => binder.id == id,
      orElse: () {
        print('Binder não encontrado, criando um novo binder.');
        return Binder(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          pages: [
            Page(
              pageNumber: 0,
              numberOfSlots: 9,
              slots: List.generate(9, (_) => null),
            ),
          ],
          coverAsset: '',
          name: 'Novo Binder',
        );
      },
    );
  }

  void addToPile(String photocard) {
    sharedPile.add(photocard);
  }

  void removeFromPile(String photocard) {
    sharedPile.remove(photocard);
  }

  Future<bool> moveToBinder(
    String photocard,
    String binderId,
    int pageIndex,
    int slotIndex,
  ) async {
    try {
      Binder binder = await getBinder(binderId);
      if (pageIndex >= 0 && pageIndex < binder.pages.length) {
        Page page = binder.pages[pageIndex];
        if (slotIndex >= 0 && slotIndex < page.slots.length) {
          if (page.slots[slotIndex] == null) {
            // Salva a posição no banco de dados
            await _dataStorageService.savePhotocardPosition(
              binderId,
              pageIndex,
              slotIndex,
              photocard,
            );

            // Atualiza o modelo em memória
            page.addPhotocard(slotIndex, photocard);
            removeFromPile(photocard);

            print(
                'Photocard movido para o binder: $binderId, Página: $pageIndex, Slot: $slotIndex');
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('Erro ao mover photocard: $e');
      return false;
    }
  }

  Future<bool> moveFromBinder(
    String binderId,
    int pageIndex,
    int slotIndex,
  ) async {
    Binder binder = await getBinder(binderId);
    if (pageIndex >= 0 && pageIndex < binder.pages.length) {
      Page page = binder.pages[pageIndex];
      if (slotIndex >= 0 && slotIndex < page.slots.length) {
        String? photocard = page.getPhotocard(slotIndex);
        if (photocard != null) {
          addToPile(photocard);
          page.removePhotocard(slotIndex);
          await updateBinderSlots(
            binder.id,
            binder.pages.expand((p) => p.nonNullSlots).toList(),
          );
          print('Photocard movido para o monte: $photocard');
          return true;
        }
      }
    }
    print('Erro ao mover photocard do binder para o monte.');
    return false;
  }

  Future<void> updateSlot(
    String binderId,
    int pageIndex,
    int slotIndex,
    String? photocard,
  ) async {
    Binder binder = await getBinder(binderId);
    if (pageIndex >= 0 && pageIndex < binder.pages.length) {
      Page page = binder.pages[pageIndex];
      if (slotIndex >= 0 && slotIndex < page.slots.length) {
        page.addPhotocard(slotIndex, photocard);
        await updateBinderSlots(
          binder.id,
          binder.pages.expand((p) => p.nonNullSlots).toList(),
        );
      }
    }
  }

  Future<void> saveState() async {
    try {
      for (var binder in binders) {
        for (var page in binder.pages) {
          await _dataStorageService.saveBinderState(
            binder.id,
            page.slots,
          );
        }
      }

      await _dataStorageService.saveSharedPileState(sharedPile);
      print('Estado do BinderManager salvo com sucesso');
    } catch (e) {
      print('Erro ao salvar estado do BinderManager: $e');
    }
  }
}
