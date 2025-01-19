# Scripts de Migração

## Preparação

1. Instalar dependências:
```bash
dart pub get
```

## Scripts Disponíveis

### Upload de Photocards
Faz upload de todas as imagens de photocards para o Firebase Storage.

```bash
dart upload_photocards.dart
```

### Migração de URLs de Photocards
Atualiza as URLs dos photocards na biblioteca online.

```bash
dart migrate_photocard_urls.dart
```

## Pré-requisitos
- Dart SDK
- Firebase CLI configurado
- Credenciais do Firebase configuradas
