CREATE SCHEMA IMO
GO

create table IMO.Cliente (
    cpf varchar(11) primary key NOT NULL,
    nome_cliente varchar(100) NOT NULL,
    telefone varchar(11) NOT NULL,
    email varchar(100) NOT NULL
)

create table IMO.Imovel (
    id_imovel int primary key Identity NOT NULL,
    endereco varchar(150) NOT NULL,
    situacao int CHECK (situacao < 0 or situacao > 4) NOT NULL, 
    cpf varchar(11) references IMO.Cliente (cpf),
    valor_aluguel int,
    valor_compra int
)

create table IMO.Funcionario (
    id_funcionario int primary key Identity NOT NULL,
    nome_funcionario varchar(100) NOT NULL,
    id_funcao int references IMO.Funcoes (id_funcao) NOT NULL
)

create table IMO.Funcoes (
	id_funcao int primary key Identity NOT NULL,
	nome_funcao varchar(20) NOT NULL,
)

create table IMO.Agendamentos (
    id_agendamento int primary key Identity NOT NULL,
    dataAtendimento date NOT NULL,
    cpf varchar(11) references IMO.Cliente (cpf),
    id_funcionario int references IMO.Funcionario (id_funcionario),
    id_imovel int references IMO.Imovel (id_imovel)
)

create table IMO.EnderecosClientes (
	-- serve pra endereços dos clientes e não dos imóveis
	id_endereco int primary key Identity NOT NULL, 
    cpf varchar(11) references IMO.Cliente (cpf),
    rua varchar(100) NOT NULL,
    numero varchar(1000) NOT NULL,
    bairro varchar(70) NOT NULL,
    cidade varchar (15) NOT NULL,
    estado varchar (2) NOT NULL
)

create table IMO.Situacao (
	id_situacao int primary key Identity NOT NULL,
	nome_situacao varchar(10) NOT NULL
)

create table IMO.Contrato (
	id_contrato int primary key Identity NOT NULL,
	cpf varchar(11) references IMO.Cliente (cpf),
	id_imovel int references IMO.Imovel (id_imovel),
	data_contrato date NOT NULL,
	data_expiracao date -- pode ser nulo caso o imóvel tenha sido comprado e não alugado
)

-- SPs:

-- StoredProcedure armazenada para inserir um novo cliente e seu endereço
CREATE OR ALTER PROCEDURE InserirClienteEndereco
    @cpf varchar(11),
    @nome_cliente varchar(100),
    @telefone int,
    @email varchar(100),
    @rua varchar(100),
    @numero varchar(1000),
    @bairro varchar(70),
    @cidade varchar(15),
    @estado varchar(2)
AS
BEGIN
    BEGIN TRANSACTION;

    INSERT INTO IMO.Cliente (cpf, nome_cliente, telefone, email)
    VALUES (@cpf, @nome_cliente, @telefone, @email);

    DECLARE @id_cliente int;
    SET @id_cliente = SCOPE_IDENTITY();

    INSERT INTO IMO.EnderecosClientes(cpf, rua, numero, bairro, cidade, estado)
    VALUES (@cpf, @rua, @numero, @bairro, @cidade, @estado);

    COMMIT;
END;

-- Stored Procedure para o funcion疵io inserir um novo imel
CREATE OR ALTER PROCEDURE InserirImovel
    @situacao int, 
	@endereco varchar(150),
    @cpf varchar(11),
    @valor_aluguel int,
    @valor_compra int
AS
BEGIN
	INSERT INTO IMO.Imovel (situacao, endereco, cpf, valor_aluguel, valor_compra)
	VALUES (@situacao, @endereco, @cpf, @valor_aluguel, @valor_compra)
END


-- Triggers:

-- Trigger para atualizar a tabela situacao de um imóvel após criar contrato
CREATE TRIGGER trAtualizarSituacaoImovel
ON IMO.Contrato
AFTER INSERT
AS
BEGIN
    UPDATE IMO.Imovel
    SET situacao = CASE
                        WHEN EXISTS (SELECT 1 FROM inserted WHERE id_imovel = inserted.id_imovel AND data_contrato <= GETDATE() AND data_expiracao >= GETDATE() AND data_expiracao IS NOT NULL)
                            THEN (SELECT venda FROM IMO.Situacao)
                        WHEN EXISTS (SELECT 1 FROM inserted WHERE id_imovel = inserted.id_imovel AND data_contrato <= GETDATE() AND data_expiracao >= GETDATE() AND data_expiracao IS NULL)
                            THEN (SELECT aluguel FROM IMO.Situacao)
                        ELSE (SELECT indisponivel FROM IMO.Situacao)
                    END
    FROM IMO.Imovel
    WHERE IMO.Imovel.id_imovel IN (SELECT id_imovel FROM inserted);
END;
-- Views:

-- Views para exibir agendamentos com detalhes de cliente e imel
CREATE VIEW vwVerAgendamentos AS
SELECT
    A.id_agendamento,
    A.dataAtendimento,
    C.cpf AS cpf_cliente,
    C.nome_cliente,
    I.id_imovel,
    I.endereco,
    I.situacao
FROM
    IMO.Agendamentos AS A
    JOIN IMO.Cliente C ON A.cpf = C.cpf
    JOIN IMO.Imovel I ON A.id_imovel = I.id_imovel;


--Views para ver ontratos com detalhes de cliente e mel
CREATE VIEW vwVerContratos AS
SELECT
    C.id_contrato,
    C.data_contrato,
    C.data_expiracao,
    Cl.cpf AS cpf_cliente,
    Cl.nome_cliente,
    I.id_imovel,
    I.endereco
FROM
    IMO.Contrato C
    JOIN IMO.Cliente Cl ON C.cpf = Cl.cpf
    JOIN IMO.Imovel I ON C.id_imovel = I.id_imovel;

-- Index

-- Index para ver imovel

CREATE INDEX inImoveis
ON IMO.Imovel (id_imovel, endereco, situacao, valor_compra, valor_aluguel)

CREATE INDEX inContratos
ON IMO.Contrato (id_contrato, data_contrato, data_expiracao)

