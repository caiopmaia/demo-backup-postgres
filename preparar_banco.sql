-- =====================================================================
-- preparar_banco.sql
-- Prepara o banco "loja_demo" para a demonstração (rodar ANTES da apresentação).
-- Uso:   psql -U postgres -d loja_demo -f preparar_banco.sql
-- Pode ser rodado de novo quantas vezes quiser: ele apaga e recria tudo.
-- =====================================================================

-- Limpa execuções anteriores (ensaios)
DROP TABLE IF EXISTS pedidos;
DROP TABLE IF EXISTS produtos;
DROP TABLE IF EXISTS clientes;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'leitor') THEN
    EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA public FROM leitor';
    EXECUTE 'REVOKE ALL ON SCHEMA public FROM leitor';
    EXECUTE 'REVOKE ALL ON DATABASE ' || quote_ident(current_database()) || ' FROM leitor';
    EXECUTE 'DROP ROLE leitor';
  END IF;
END $$;

-- Tabelas
CREATE TABLE clientes (
    id        SERIAL PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL,
    email     VARCHAR(100) UNIQUE NOT NULL,
    cidade    VARCHAR(50)
);

CREATE TABLE produtos (
    id        SERIAL PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL,
    preco     NUMERIC(10,2) NOT NULL,
    estoque   INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE pedidos (
    id          SERIAL PRIMARY KEY,
    cliente_id  INTEGER NOT NULL REFERENCES clientes(id),
    produto_id  INTEGER NOT NULL REFERENCES produtos(id),
    quantidade  INTEGER NOT NULL,
    data_pedido DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Dados
INSERT INTO clientes (nome, email, cidade) VALUES
  ('Ana Souza',      'ana@email.com',      'Recife'),
  ('Bruno Lima',     'bruno@email.com',    'Olinda'),
  ('Carla Mendes',   'carla@email.com',    'Jaboatão'),
  ('Diego Ferreira', 'diego@email.com',    'Recife'),
  ('Elisa Rocha',    'elisa@email.com',    'Paulista');

INSERT INTO produtos (nome, preco, estoque) VALUES
  ('Notebook',  3500.00, 10),
  ('Mouse',       80.00, 50),
  ('Teclado',    150.00, 30),
  ('Monitor',    900.00, 15),
  ('Headset',    250.00, 20);

INSERT INTO pedidos (cliente_id, produto_id, quantidade, data_pedido) VALUES
  (1, 1, 1, '2026-10-01'),
  (2, 2, 2, '2026-10-03'),
  (3, 4, 1, '2026-10-05'),
  (1, 3, 1, '2026-10-08'),
  (4, 5, 3, '2026-10-10'),
  (5, 2, 1, '2026-10-12'),
  (2, 1, 1, '2026-10-15'),
  (4, 4, 2, '2026-10-20');

SELECT 'Banco pronto: ' || (SELECT count(*) FROM clientes) || ' clientes, '
                        || (SELECT count(*) FROM produtos) || ' produtos, '
                        || (SELECT count(*) FROM pedidos)  || ' pedidos.' AS status;
