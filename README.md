# Demo: Backup, Recuperação e Monitoramento no PostgreSQL

Demonstração prática para a apresentação sobre administração de banco de dados. Em poucos minutos, ela mostra:

1. **Menor privilégio**: um usuário só de leitura consegue consultar, mas o banco recusa quando ele tenta apagar.
2. **Backup**: `pg_dump` gera um arquivo SQL com o banco inteiro.
3. **Desastre**: uma tabela é apagada de propósito com `DROP TABLE`.
4. **Restauração**: o backup é aplicado com `psql` e a tabela volta com todos os dados.
5. **Monitoramento**: `pg_stat_activity` mostra quem está conectado e o que cada conexão está executando.

## Arquivos

| Arquivo | O que é |
|---|---|
| [`preparar_banco.sql`](preparar_banco.sql) | Cria o banco de exemplo (uma loja com `clientes`, `produtos` e `pedidos`). Pode ser rodado de novo para resetar tudo. |
| [`roteiro-mac.md`](roteiro-mac.md) | Passo a passo completo no macOS (Postgres.app), com os comandos e a fala de cada passo |
| [`roteiro-windows.md`](roteiro-windows.md) | O mesmo roteiro para Windows (instalador oficial + PowerShell) |

## Início rápido

Pré-requisito: PostgreSQL 12 ou mais recente, com `psql`, `pg_dump` e `createdb` no PATH. A instalação está explicada em cada roteiro.

```bash
git clone <url-deste-repo>
cd demo-backup-postgres

createdb -U postgres loja_demo
psql -U postgres -d loja_demo -f preparar_banco.sql
```

Deve aparecer `Banco pronto: 5 clientes, 5 produtos, 8 pedidos.` Depois é só seguir o roteiro do seu sistema.

## Resumo dos comandos da demo

```sql
-- 1. Usuário só de leitura (como postgres)
CREATE ROLE leitor LOGIN PASSWORD 'leitor123';
GRANT CONNECT ON DATABASE loja_demo TO leitor;
GRANT USAGE ON SCHEMA public TO leitor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO leitor;
-- como leitor: SELECT funciona, DELETE dá "permission denied"
```

```bash
# 2. Backup
pg_dump -U postgres -d loja_demo --clean --if-exists -f backup_loja.sql

# 3. Desastre
psql -U postgres -d loja_demo -c "DROP TABLE pedidos;"

# 4. Restauração
psql -U postgres -d loja_demo -q -f backup_loja.sql
```

```sql
-- 5. Monitoramento
SELECT pid, usename, datname, client_addr, state,
       now() - query_start AS tempo, left(query, 50) AS consulta
FROM pg_stat_activity
WHERE datname IS NOT NULL;
```

## Detalhes que evitam problemas

- **`--clean --if-exists` no `pg_dump`:** o backup apaga e recria cada objeto ao ser restaurado. Sem isso, restaurar por cima do banco existente daria erros de "já existe" e duplicaria os dados das tabelas que não foram apagadas.
- **Apague `pedidos`, não `clientes`:** `clientes` é referenciada por chave estrangeira, então o `DROP` dela falharia.
- **O backup também guarda as permissões:** depois da restauração, o `leitor` continua conseguindo ler a tabela `pedidos`.
- **Reset para ensaiar:** rodar `preparar_banco.sql` de novo apaga as tabelas e o usuário `leitor` e recria tudo do zero.

Testado no PostgreSQL 16.

## Referências

- [Documentação do PostgreSQL: Backup and Restore](https://www.postgresql.org/docs/current/backup.html)
- [Documentação do PostgreSQL: `pg_stat_activity`](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)
- [Documentação do PostgreSQL: `GRANT`](https://www.postgresql.org/docs/current/sql-grant.html)
