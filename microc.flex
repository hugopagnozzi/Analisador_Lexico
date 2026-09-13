/*
 * microc.flex
 *
 * Esqueleto do analisador lexico (scanner) para a linguagem Micro C.
 * Disciplina: Compiladores I - FACOM
 *
 * Compilacao:
 *      flex microc.flex
 *      gcc lex.yy.c -o lexer
 *
 * Uso:
 *      ./lexer test.mc
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------------------------------------------------------------------
 * 1. VOCABULARIO DE TOKENS (equivalente a tokens.h)
 * ------------------------------------------------------------------- */

typedef enum 
{
    /* Tokens fundamentais */

    UNDEF,          /* token indefinido (usado para reportar erros) */
    ID,             /* identificador                                */
    END_OF_FILE,    /* fim de arquivo                               */

    /* Constantes literais */

    INTEGERCONST,
    CHARCONST,
    STRINGCONST,

    /* Operadores aritmeticos */

    PLUS, MINUS, MUL, DIV, MOD,

    /* Operadores relacionais e logicos */

    EQ, NEQ, LT, GT, LEQ, GEQ, AND, OR, NOT,

    /* Simbolos de atribuicao e pontuacao */

    ASSIGN, SEMICOLON, COMMA, LPAREN, RPAREN,
    LBRACE, RBRACE, LBRACKET, RBRACKET,

    /* Palavras reservadas */

    MAIN, IF, ELSE, FOR, RETURN, INT, CHAR, PRINT
} 
TokenType;

/* Nomes dos tokens, usados apenas pelo main() de teste abaixo para
 * imprimir o tipo de cada token de forma legivel. Mantenha esta lista
 * na MESMA ORDEM do enum TokenType. */

static const char *nome_token[] = 
{
    "UNDEF", "ID", "END_OF_FILE",
    "INTEGERCONST", "CHARCONST", "STRINGCONST",
    "PLUS", "MINUS", "MUL", "DIV", "MOD",
    "EQ", "NEQ", "LT", "GT", "LEQ", "GEQ", "AND", "OR", "NOT",
    "ASSIGN", "SEMICOLON", "COMMA", "LPAREN", "RPAREN",
    "LBRACE", "RBRACE", "LBRACKET", "RBRACKET",
    "MAIN", "IF", "ELSE", "FOR", "RETURN", "INT", "CHAR", "PRINT"
};

/* Número de tokens, usado para identificar a palavra reservada. */

static const int num_tokens = 37;

/* Número de palavras reservadas, usado para percorrer a lista de palavras
 * reservadas e identificar a palavra reservada. */

static const int num_palavras_reservadas = 8;

/* Lista de palavras reservadas, usada para verificação quando o token for
 * um ID. */

static const char *palavras_reservadas[] = 
{
    "main", "if", "else", "for", "return", "int", "char", "print"
};

/* Valor semantico do token corrente. */

typedef struct 
{
    char *symbol;      /* lexema para ID, INTEGERCONST, CHARCONST, STRINGCONST */
    char *error_msg;   /* mensagem de erro, usada apenas quando tipo == UNDEF   */
} 
YYSTYPE;

YYSTYPE microc_yylval;

/* Nos da lista encadeada usada como tabela de strings. */

typedef struct Node
{
    char *lexema;           /* lexemas armazenados */
    struct Node *prox_no;   /* ponteiro para o proximo no */
} 
Node;

Node *tabela_strings = NULL;

/* Funcoes para manipular a tabela de strings */

void imprime_tabela(void)
{
    Node *p;

    for(p = tabela_strings; p != NULL; p = p->prox_no)
    {
        printf("%s\n", p->lexema);
    }
}

Node* busca_tabela(char *lexema)
{
    Node *p = tabela_strings;

    while(p != NULL)
    {
        if(strcmp(p->lexema, lexema) == 0)
        {
            return p;   /* Encontrou */
        }
        p = p->prox_no;
    }

    return NULL;    /* Nao encontrou */
}

char* add_tabela(char *lexema)
{
    Node *p;
    Node *novo;

    /* Busca na tabela para nao duplicar lexemas */

    p = busca_tabela(lexema);

    if(p != NULL)
    {
        return p->lexema;
    }

    /* Cria o novo no */

    novo = (Node *) malloc(sizeof(Node));

    if(novo == NULL)
    {
        fprintf(stderr, "Erro: Falha ao alocar memoria.\n");
        exit(1);
    }

    novo->prox_no = NULL;
    novo->lexema = strdup(lexema);

    /* Insere o novo no na tabela de strings */

    if(tabela_strings == NULL)
    {
        tabela_strings = novo;
    }
    else
    {
        p = tabela_strings;
        while(p->prox_no != NULL)
        {
            p = p->prox_no;
        }
        p->prox_no = novo;
    }

    return novo->lexema;
}

/* Funcoes auxiliares para preencher microc_yylval.symbol com um ponteiro para
 * o texto reconhecido (yytext). */

static void guarda_lexema(void) 
{
    microc_yylval.symbol = add_tabela(yytext);
}

static void guarda_lexema_str_char(void) 
{
    int j = 0;
    int tam = strlen(yytext);
    char *dest = malloc(tam);   /* Aloca espaço suficiente (será menor ou igual a yytext) */

    if(dest == NULL)
    {
        fprintf(stderr, "Erro: Falha ao alocar memoria.\n");
        exit(1);
    }

    /* Ignora a primeira e a última aspa */

    for (int i = 1; i < tam-1; i++) 
    {
        if (yytext[i] == '\\' &&  i+1 < tam-1) 
        {
            i++;    /* Pula a barra */
            switch (yytext[i]) 
            {
                case 'n': 
                    dest[j++] = '\n'; 
                    break;
                case 't': 
                    dest[j++] = '\t'; 
                    break;
                case '\\': 
                    dest[j++] = '\\'; 
                    break;
                case '\"': 
                    dest[j++] = '\"'; 
                    break;
                default:  
                    dest[j++] = yytext[i]; 
                    break;
            }
        } 
        else 
        {
            dest[j++] = yytext[i];
        }
    }

    dest[j] = '\0';     /* Fecha a string */
    microc_yylval.symbol = add_tabela(dest);
    free(dest);
}

/* Linha atual e coluna atual do arquivo-fonte sendo processado. */

int linha_atual = 1;
int coluna_atual = 1;

/* Linha e coluna indicando onde o erro lexico comecou. */

int linha_erro = 1;
int coluna_erro = 1;

%}

/* -----------------------------------------------------------------------
 * 2. SECAO DE DEFINICOES
 * ------------------------------------------------------------------- */

DIGIT       [0-9]
LETRA       [a-zA-Z_]
ALFANUM     [a-zA-Z0-9_]
ESCAPE      \\[nt"0\\]

%x COMMENT
%x STRING
%x CHAR

%%

 /* -----------------------------------------------------------------------
  * 3. SECAO DE REGRAS
  * --------------------------------------------------------------------- */

 /* --- Fim de arquivo -----------------------------------------------------
  * Tratada explicitamente (em vez de depender do retorno automatico 0
  * do flex), pois o token UNDEF tambem vale 0 no enum TokenType -- se
  * dependessemos do comportamento padrao, um erro lexico seria
  * confundido com o fim do arquivo pelo main() de teste abaixo. */

<<EOF>>             {
                        return END_OF_FILE; 
                    }

 /* --- Espacos em branco e quebras de linha ---------------------------- */

\n                  { 
                        linha_atual++;
                        coluna_atual = 1;
                    }

[ \t\r]+            { 
                        coluna_atual += yyleng; 
                    }

 /* --- Caracteres de escape -------------------------------------------- */

{ESCAPE}            { 
                        microc_yylval.error_msg = strdup(yytext);
                        coluna_erro = coluna_atual;
                        linha_erro = linha_atual;
                        coluna_atual += yyleng;
                        return UNDEF;
                    }

 /* --- Comentarios ------------------------------------------------------
  * Estes ja estao implementados como exemplo de uso de estados (%x) e
  * de tratamento de erro via EOF dentro de um estado especial. */

"//".*              { 
                        /* comentario de linha: ignora ate o fim da linha */ 
                    }

"/*"                { 
                        BEGIN(COMMENT); 
                        coluna_atual += yyleng;
                    }

<COMMENT>"*/"       { 
                        BEGIN(INITIAL); 
                        coluna_atual += yyleng;
                    }

<COMMENT>\n         { 
                        linha_atual++; 
                    }

<COMMENT>.          { 
                        coluna_atual += yyleng; 
                    }

 /* Fechamento de comentario sem abertura correspondente. */

"*/"                {
                        microc_yylval.error_msg = "Comentario nao iniciado";
                        return UNDEF;
                    }

 /* --- Palavras reservadas e identificadores --------------------------- */

{LETRA}{ALFANUM}*   {
                        coluna_atual += yyleng;
                        for(int i = 0; i < num_palavras_reservadas; i++)
                        {
                            if(strcmp(palavras_reservadas[i], yytext) == 0)
                            {
                                return (num_tokens - num_palavras_reservadas + i);
                            }
                        }
                        guarda_lexema();
                        return ID;
                    }

"-"?{DIGIT}+{LETRA}{ALFANUM}*   {
                                    microc_yylval.error_msg = "Identificador nao pode comecar com numero";
                                    coluna_erro = coluna_atual;
                                    linha_erro = linha_atual;
                                    coluna_atual += yyleng;
                                    return UNDEF;
                                }

 /* --- Constantes inteiras --------------------------------------------- */

"-"?{DIGIT}+        {
                        guarda_lexema();
                        coluna_atual += yyleng;
                        return INTEGERCONST;
                    }

 /* --- Constantes de caractere ----------------------------------------- */

'({ESCAPE}|[^'\n])?'        {
                                if(memchr(yytext, '\0', yyleng) != NULL)
                                {
                                    microc_yylval.error_msg = "CHAR contem caractere nulo";
                                    coluna_erro = coluna_atual;
                                    linha_erro = linha_atual;
                                    coluna_atual += yyleng;
                                    return UNDEF;
                                }
                                guarda_lexema_str_char();
                                coluna_atual += yyleng;
                                return CHARCONST;
                            }

'({ESCAPE}|[^'\n]){2,}'     {
                                microc_yylval.error_msg = "CHAR nao pode conter mais de um caractere";
                                coluna_erro = coluna_atual;
                                linha_erro = linha_atual;
                                coluna_atual += yyleng;
                                return UNDEF;
                            }

'({ESCAPE}|[^'\n])*\n       {
                                microc_yylval.error_msg = "CHAR nao terminado";
                                coluna_erro = coluna_atual;
                                linha_erro = linha_atual;
                                linha_atual++;
                                coluna_atual = 1;
                                return UNDEF;
                            }

'                   {
                        BEGIN(CHAR);
                    }

 /* --- Constantes de string -------------------------------------------- */

\"([^\n"\\]|\\.)*\"     {
                            if(memchr(yytext, '\0', yyleng) != NULL)
                            {
                                microc_yylval.error_msg = "STRING contem caractere nulo";
                                coluna_erro = coluna_atual;
                                linha_erro = linha_atual;
                                coluna_atual += yyleng;
                                return UNDEF;
                            }
                            guarda_lexema_str_char();
                            coluna_atual += yyleng;
                            return STRINGCONST;
                        }

\"([^\n"\\]|\\.)*\n     {
                            microc_yylval.error_msg = "STRING nao terminada";
                            coluna_erro = coluna_atual;
                            linha_erro = linha_atual;
                            linha_atual++;
                            coluna_atual = 1;
                            return UNDEF;
                        }

\"                  {
                        BEGIN(STRING);
                    }

 /* --- Operadores relacionais e logicos -------------------------------- */

"=="                { 
                        coluna_atual += yyleng;
                        return EQ; 
                    }

"="                 { 
                        coluna_atual += yyleng;
                        return ASSIGN; 
                    }

"!="                {
                        coluna_atual += yyleng;
                        return NEQ;
                    }

"!"                 {
                        coluna_atual += yyleng;
                        return NOT;
                    }

"<="                {
                        coluna_atual += yyleng;
                        return LEQ;
                    }

"<"                 {
                        coluna_atual += yyleng;
                        return LT;
                    }

">="                {
                        coluna_atual += yyleng;
                        return GEQ;
                    }

">"                 {
                        coluna_atual += yyleng;
                        return GT;
                    }

"&&"                {
                        coluna_atual += yyleng;
                        return AND;
                    }

"||"                {
                        coluna_atual += yyleng;
                        return OR;
                    }

 /* --- Operadores aritmeticos e simbolos de pontuacao ------------------ */

"+"                 { 
                        coluna_atual += yyleng;
                        return PLUS; 
                    }

"-"                 { 
                        coluna_atual += yyleng;
                        return MINUS; 
                    }

"*"                 { 
                        coluna_atual += yyleng;
                        return MUL; 
                    }

"/"                 { 
                        coluna_atual += yyleng;
                        return DIV; 
                    }

"%"                 { 
                        coluna_atual += yyleng;
                        return MOD; 
                    }

";"                 { 
                        coluna_atual += yyleng;
                        return SEMICOLON; 
                    }

","                 { 
                        coluna_atual += yyleng;
                        return COMMA; 
                    }

"("                 { 
                        coluna_atual += yyleng;
                        return LPAREN; 
                    }

")"                 { 
                        coluna_atual += yyleng;
                        return RPAREN; 
                    }

"{"                 { 
                        coluna_atual += yyleng;
                        return LBRACE; 
                    }

"}"                 { 
                        coluna_atual += yyleng;
                        return RBRACE; 
                    }

"["                 { 
                        coluna_atual += yyleng;
                        return LBRACKET; 
                    }

"]"                 { 
                        coluna_atual += yyleng;
                        return RBRACKET; 
                    }

 /* --- Caractere invalido -------------------------------------------------
  * Casa com qualquer caractere que nao tenha correspondido a nenhuma
  * regra anterior. Deve ser SEMPRE a ultima regra do arquivo. */

.                   {
                        microc_yylval.error_msg = strdup(yytext);
                        coluna_erro = coluna_atual;
                        linha_erro = linha_atual;
                        coluna_atual += yyleng;
                        return UNDEF;
                    }

%%

/* -----------------------------------------------------------------------
 * 4. SUB-ROTINAS DO USUARIO
 * ------------------------------------------------------------------- */

/* yywrap: informa ao flex que, ao atingir o EOF, a leitura deve
 * simplesmente parar (nao ha um proximo arquivo a processar). */

int yywrap(void) 
{
    return 1;
}

/* main() de teste: le o arquivo passado como argumento e imprime, para
 * cada token reconhecido, seu tipo, lexema e linha */

int main(int argc, char **argv) 
{
    if (argc < 2) 
    {
        fprintf(stderr, "Uso: %s <arquivo.mc>\n", argv[0]);
        return 1;
    }

    FILE *arquivo_fonte = fopen(argv[1], "r");

    if (!arquivo_fonte) 
    {
        fprintf(stderr, "Erro: nao foi possivel abrir o arquivo '%s'\n", argv[1]);
        return 1;
    }

    yyin = arquivo_fonte;
    int tipo;

    while ((tipo = yylex()) != END_OF_FILE) 
    {
        if (tipo == UNDEF) 
        {
            fprintf(stderr, "ERRO LEXICO (linha %d, coluna %d): %s\n", linha_erro, coluna_erro, microc_yylval.error_msg);
            continue;
        }
        printf("Token: tipo = %-13s lexema = (%s)  linha = %d\n", nome_token[tipo], yytext, linha_atual);
    }

    if(YY_START == STRING)
    {
        BEGIN(INITIAL);
        microc_yylval.error_msg = "EOF em STRING";
        coluna_erro = coluna_atual;
        linha_erro = linha_atual;
        fprintf(stderr, "ERRO LEXICO (linha %d, coluna %d): %s\n", linha_erro, coluna_erro, microc_yylval.error_msg);
    }

    else if(YY_START == CHAR)
    {
        BEGIN(INITIAL);
        microc_yylval.error_msg = "EOF em CHAR";
        coluna_erro = coluna_atual;
        linha_erro = linha_atual;
        fprintf(stderr, "ERRO LEXICO (linha %d, coluna %d): %s\n", linha_erro, coluna_erro, microc_yylval.error_msg);
    }

    else if(YY_START == COMMENT)
    {
        BEGIN(INITIAL);
        microc_yylval.error_msg = "EOF em comentario";
        coluna_erro = coluna_atual;
        linha_erro = linha_atual;
        fprintf(stderr, "ERRO LEXICO (linha %d, coluna %d): %s\n", linha_erro, coluna_erro, microc_yylval.error_msg);
    }

    else
    {
        printf("Token: tipo = %-13s lexema = ()  linha = %d\n", nome_token[tipo], linha_atual);
    }

    fclose(arquivo_fonte);
    return 0;
}
