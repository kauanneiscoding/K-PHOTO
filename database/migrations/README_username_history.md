# Sistema de Histórico de Usernames

## Descrição
Implementação do sistema que permite troca de username a cada 30 dias, guardando usernames antigos na tabela `username_history` por 30 dias para evitar reuso imediato.

## Arquivos Criados

### 1. Tabela username_history
- **Arquivo**: `create_username_history_table.sql`
- **Função**: Armazena usernames antigos com data de expiração (30 dias)
- **Campos**:
  - `id`: UUID primário
  - `user_id`: ID do usuário (FK)
  - `username`: Username antigo
  - `changed_at`: Data da troca
  - `expires_at`: Data em que pode ser reutilizado

### 2. Trigger Automático
- **Arquivo**: `create_username_history_trigger.sql`
- **Função**: Salva automaticamente o username antigo no histórico quando é alterado
- **Vantagem**: Garante que nenhum username antigo seja perdido

### 3. Serviço Dart
- **Arquivo**: `lib/services/username_history_service.dart`
- **Funções**:
  - `saveUsernameToHistory()`: Salva manualmente no histórico
  - `isUsernameAvailable()`: Verifica disponibilidade completa
  - `cleanupExpiredUsernames()`: Limpa registros expirados
  - `getUserUsernameHistory()`: Obtém histórico do usuário

## Como Aplicar as Migrações

### Passo 1: Criar a Tabela
```sql
-- Execute no Supabase SQL Editor
-- Copie e cole o conteúdo de create_username_history_table.sql
```

### Passo 2: Criar o Trigger
```sql
-- Execute no Supabase SQL Editor  
-- Copie e cole o conteúdo de create_username_history_trigger.sql
```

### Passo 3: Verificar Funcionamento
1. **Teste troca de username**: Altere o username de um usuário
2. **Verifique histórico**: Consulte a tabela `username_history`
3. **Teste disponibilidade**: Tente usar username antigo (deve ser bloqueado)
4. **Aguarde 30 dias**: Após expiração, username deve ficar disponível

## Fluxo Completo

1. **Usuário troca username**:
   - Trigger salva username antigo automaticamente
   - Data de expiração definida para 30 dias
   - `last_username_change` atualizado

2. **Verificação de disponibilidade**:
   - Verifica uso atual
   - Verifica histórico (não expirado)
   - Retorna disponível apenas se não estiver em nenhum

3. **Mensagens de erro**:
   - "Este nome de usuário já está em uso" (uso atual)
   - "Este nome de usuário não pode ser usado agora..." (histórico)

## Manutenção

### Limpeza Automática
```sql
-- Execute periodicamente (ex: job semanal)
SELECT cleanup_expired_usernames();
```

### Consultas Úteis
```sql
-- Verificar usernames expirados
SELECT * FROM username_history WHERE expires_at < NOW();

-- Histórico de um usuário
SELECT username, changed_at, expires_at 
FROM username_history 
WHERE user_id = 'user_uuid' 
ORDER BY changed_at DESC;

-- Usernames que expiram em breve
SELECT username, expires_at 
FROM username_history 
WHERE expires_at BETWEEN NOW() AND NOW() + INTERVAL '7 days';
```

## Segurança

- **Índices**: Criados para performance em consultas
- **Constraints**: Validação de tamanho (3-50 caracteres)
- **FK Cascade**: Remove histórico se usuário for deletado
- **Único**: Evita duplicatas de mesmo username para mesmo usuário
