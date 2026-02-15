# Sistema de Temas de Perfil

## Visão Geral

O sistema de temas de perfil permite que os usuários personalizem a aparência de seus perfis com diferentes esquemas de cores.

## Temas Disponíveis

### 1. Rosa (Padrão)
- Cor primária: Rosa (#E91E63)
- Secundária: Rosa claro (#F48FB1)
- Fundo: Rosa muito claro (#FCE4EC)
- Ideal para: Usuários que preferem o visual original

### 2. Roxo Pastel
- Cor primária: Roxo (#9C27B0)
- Secundária: Roxo claro (#CE93D8)
- Fundo: Roxo muito claro (#F3E5F5)
- Ideal para: Usuários que gostam de tons suaves de roxo

### 3. Claro
- Cor primária: Azul (#2196F3)
- Secundária: Azul claro (#90CAF9)
- Fundo: Azul muito claro (#E3F2FD)
- Ideal para: Usuários que preferem um visual limpo e profissional

### 4. Escuro
- Cor primária: Cinza escuro (#424242)
- Secundária: Cinza médio (#616161)
- Fundo: Preto (#121212)
- Ideal para: Usuários que preferem modo escuro

## Implementação

### Arquivos Principais

1. **`lib/models/profile_theme.dart`**: Modelo de dados dos temas
2. **`lib/widgets/theme_selector.dart`**: Widget para seleção de temas
3. **`lib/pages/edit_profile_page.dart`**: Página de edição com seleção de temas
4. **`lib/profile_page.dart`**: Visualização do perfil com tema aplicado

### Banco de Dados

A tabela `user_profile` contém o campo `theme` que armazena o tema selecionado:
- Tipo: VARCHAR(20)
- Valores possíveis: 'pink', 'purple', 'light', 'dark'
- Padrão: 'pink'

### Migration

```sql
ALTER TABLE user_profile ADD COLUMN theme VARCHAR(20) DEFAULT 'pink';
UPDATE user_profile SET theme = 'pink' WHERE theme IS NULL;
```

## Como Usar

### Para Selecionar um Tema

1. Vá para a página de perfil
2. Clique em "Editar perfil"
3. Role até a seção "Tema do Perfil"
4. Selecione o tema desejado
5. Salve as alterações

### Para Adicionar um Novo Tema

1. Adicione o novo valor ao enum `ProfileThemeType`
2. Crie uma nova instância `static const ProfileTheme`
3. Adicione à lista `allThemes`
4. Atualize a migration do banco de dados se necessário

## Personalização

Cada tema define as seguintes cores:

- `primaryColor`: Cor principal para títulos e elementos importantes
- `secondaryColor`: Cor secundária para destaques
- `backgroundColor`: Cor de fundo principal
- `surfaceColor`: Cor para containers e cards
- `textColor`: Cor para textos principais
- `usernameColor`: Cor específica para o username
- `accentColor`: Cor para ícones e elementos interativos
- `isDark`: Indica se é um tema escuro

## Considerações

- O tema é salvo no perfil do usuário e persiste entre sessões
- Todos os elementos do perfil respeitam o tema selecionado
- O tema padrão é Rosa para manter compatibilidade com usuários existentes
- A mudança de tema é aplicada imediatamente após salvar
