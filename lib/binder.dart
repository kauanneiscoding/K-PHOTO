// Renomeando de Page para BinderPage
class BinderPage {
  final int pageNumber;
  List<String?> slots;

  BinderPage({
    required this.pageNumber,
    required int numberOfSlots,
  }) : slots = List<String?>.filled(numberOfSlots, null);

  // Método para adicionar um photocard a um slot específico na página
  void addPhotocard(int slotIndex, String? photocardPath) {
    if (slotIndex >= 0 && slotIndex < slots.length) {
      slots[slotIndex] = photocardPath;
    } else {
      throw RangeError('slotIndex deve estar entre 0 e ${slots.length - 1}');
    }
  }

  // Método para remover um photocard de um slot específico na página
  void removePhotocard(int slotIndex) {
    if (slotIndex >= 0 && slotIndex < slots.length) {
      slots[slotIndex] = null;
    } else {
      throw RangeError('slotIndex deve estar entre 0 e ${slots.length - 1}');
    }
  }

  // Método para obter o photocard de um slot específico na página
  String? getPhotocard(int slotIndex) {
    if (slotIndex >= 0 && slotIndex < slots.length) {
      return slots[slotIndex];
    }
    throw RangeError('slotIndex deve estar entre 0 e ${slots.length - 1}');
  }

  // Método para obter a lista de slots
  List<String?> getSlots() => slots;

  // Método para obter o número de slots
  int getNumberOfSlots() => slots.length;
}

// Representa um binder com múltiplas páginas
class Binder {
  final String id; // ID único do binder
  final List<BinderPage> pages; // Lista de páginas do binder
  final String coverAsset; // Caminho da imagem da capa do binder
  final String name; // Nome do binder
  bool isOpen; // Estado de aberto/fechado do binder

  Binder({
    required this.id,
    List<BinderPage>? pages, // Agora é opcional passar páginas
    required this.coverAsset,
    required this.name,
    this.isOpen = false,
  }) : pages = pages ??
            [
              BinderPage(pageNumber: 1, numberOfSlots: 9)
            ]; // Se não passar páginas, cria uma com 9 slots.

  // Método para adicionar uma nova página ao binder
  void addPage(BinderPage page) {
    pages.add(page);
  }

  // Método para remover uma página do binder
  void removePage(int pageIndex) {
    if (pages.length > 1) {
      // Não permite remover a última página
      if (pageIndex >= 0 && pageIndex < pages.length) {
        pages.removeAt(pageIndex);
      } else {
        throw RangeError('pageIndex deve estar entre 0 e ${pages.length - 1}');
      }
    } else {
      throw Exception('Não é possível remover a última página do binder');
    }
  }

  // Funções para adicionar e remover photocards de uma página específica no binder
  void addPhotocardToPage(int pageIndex, int slotIndex, String? photocardPath) {
    if (pageIndex >= 0 && pageIndex < pages.length) {
      pages[pageIndex].addPhotocard(slotIndex, photocardPath);
    } else {
      throw RangeError('pageIndex deve estar entre 0 e ${pages.length - 1}');
    }
  }

  void removePhotocardFromPage(int pageIndex, int slotIndex) {
    if (pageIndex >= 0 && pageIndex < pages.length) {
      pages[pageIndex].removePhotocard(slotIndex);
    } else {
      throw RangeError('pageIndex deve estar entre 0 e ${pages.length - 1}');
    }
  }

  // Método para obter o photocard de uma página e slot específicos
  String? getPhotocardFromPage(int pageIndex, int slotIndex) {
    if (pageIndex >= 0 && pageIndex < pages.length) {
      return pages[pageIndex].getPhotocard(slotIndex);
    }
    throw RangeError('pageIndex deve estar entre 0 e ${pages.length - 1}');
  }

  // Método para obter o número total de páginas
  int getNumberOfPages() => pages.length;

  // Método para alternar o estado de aberto/fechado do binder
  void toggleOpen() {
    isOpen = !isOpen;
  }
}
