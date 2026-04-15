DOCUMENTO DE CONTEXTO: BOI DELIVERY MOBILE ERP
1. Visão Geral e Objetivo Central
    O aplicativo é um módulo móvel (Offline-First) do sistema ERP "Boi Delivery". O seu objetivo final é ser um Controle de Jornada Completo para os motoristas. Ele substitui os blocos de notas de papel, permitindo o registo exato da pesagem de saída (carregamento no abatedouro) e das pesagens de entrega (vendas aos clientes), gerando relatórios de rota e talões impressos via Bluetooth.

2. Limites do Sistema (Scope Boundaries)

    O motorista é o Operador Logístico, não o Financeiro: O aplicativo regista as vendas e as cargas, mas NÃO faz a gestão de pagamentos, cobranças ou baixas de títulos. O acerto financeiro é de responsabilidade exclusiva do    escritório (ERP Desktop/Web).

3. Fluxo Principal de Navegação (User Flow)

    - Acesso: Login seguro com Nome de Utilizador e Palavra-passe.

    - Dashboard (Central de Comando):

        - Cabeçalho com a Data Atual.

        - Filtro de Data/Período (Padrão: "Hoje").

        - Lista de Vendas/Entregas (filtrada pelo período selecionado).

        - Botão de Sincronização Global (Nuvem).

        - Botão Flutuante (FAB) para "Nova Venda/Entrega".

    - Menu Principal (Drawer/Sidebar):

        - Cadastro de Emergência de Clientes (Offline).

        - Cadastro de Emergência de Produtos (Offline).

        - Módulo de Impressão de Relatórios Diários.

4. Regras de Negócio de Vendas e Sincronização

    - Modo Offline: Todo o CRUD (Criar, Ler, Atualizar, Eliminar) de vendas é feito primeiro no SQLite do tablet.

    - Pré-Sincronização: A venda pode ser editada ou apagada livremente enquanto o status for pendente.

    - Pós-Sincronização: Se a nota já foi enviada para o ERP, ela é bloqueada. O motorista só pode solicitar edição/exclusão, o que enviará um alerta para o escritório aprovar, garantindo a integridade dos dados fiscais e de stock.

5. Sistema de Relatórios Diários (Impressão/Envio)
O app deve gerar dois resumos críticos do dia:

    - Relatório de Carregamento (Romaneio de Saída): Detalha e resume o que o motorista pesou e colocou no camião no abatedouro frigorífico.

    - Relatório de Entregas (Fecho de Rota): Detalha e resume a movimentação total de vendas e entregas realizadas aos clientes naquele dia.

6. Visão de Futuro (Roadmap V2)

    - Integração de módulo de agendamento: Pedidos feitos diretamente ao dono pelo cliente cairão no ERP e aparecerão na rota do motorista no aplicativo como "Entregas Agendadas".