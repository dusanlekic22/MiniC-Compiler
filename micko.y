%{
  #include <stdio.h>
  #include <stdlib.h>
  #include "defs.h"
  #include "symtab.h"
  #include "codegen.h"

  int yyparse(void);
  int yylex(void);
  int yyerror(char *s);
  void warning(char *s);

  extern int yylineno;
  int out_lin = 0;
  char char_buffer[CHAR_BUFFER_LENGTH];
  unsigned tip = 0;
  int error_count = 0;
  int warning_count = 0;
  int var_num = 0;
  int fun_idx = -1;
  int fcall_idx = -1;
  int fcall_ind = 0;
  int lab_num = -1;
  int arg_num = 0;
  int par_num = 0;
  int f_num = 0;
  int return_exist = 0;
  int log_exist = 0;
  int sub_par = 0;
  unsigned argumenti[500];
  FILE *output;
  unsigned args[200];
%}

%union {
  int i;
  char *s;
}

%token <i> _TYPE
%token _IF
%token _ELSE
%token _RETURN
%token <s> _ID
%token <s> _INT_NUMBER
%token <s> _UINT_NUMBER
%token _LPAREN
%token _RPAREN
%token _LBRACKET
%token _RBRACKET
%token _ASSIGN
%token _SEMICOLON
%token _COLON
%token _QMARK
%token _COMMA
%token _INC
%token _PERCENT
%token _OIAI
%token _HANA
%token _BRANCH
%token _ONE
%token _TWO
%token _THREE
%token _OTHER
%token _ENDBRANCH
%token _ARROW
%token <i> _AROP
%token <i> _RELOP
%token <i> _AND
%token <i> _OR

%type <i> num_exp exp literal
%type <i> function_call rel_exp if_part cond_exp cond_op 
%type <i> argument argument_list parameter parameter_list 
%type <i> oiai_statement rel_exps 

%nonassoc ONLY_IF
%nonassoc _ELSE

%nonassoc _OR
%nonassoc _AND

%left _INC
%left _ASSIGN
%left _AROP

%%

program
  : g_variable_list function_list
      {  
        if(lookup_symbol("main", FUN) == NO_INDEX)
          err("undefined reference to 'main'");
      }
  ;

function_list
  : function
  | function_list function
  ;

function
  : _TYPE _ID
      {
        f_num++;
        fun_idx = lookup_symbol($2, FUN);
        if(fun_idx == NO_INDEX)
          fun_idx = insert_symbol($2, FUN, $1, NO_ATR, NO_ATR);
        else 
          err("redefinition of function '%s'", $2);

        code("\n%s:", $2);
        code("\n\t\tPUSH\t%%14");
        code("\n\t\tMOV \t%%15,%%14");
      }
    _LPAREN parameter_list _RPAREN body
      {
        clear_symbols(fun_idx + 1);
        code("\n@%s_exit:", $2);
        code("\n\t\tMOV \t%%14,%%15");
        code("\n\t\tPOP \t%%14");
        code("\n\t\tRET");
        var_num = 0;
        par_num = 0;
      }
  ;

parameter_list
  :  /* empty */
    { 
    $$ = 0; 
    set_atr1(fun_idx, 0);
    sub_par = 0;
    }
  | parameters 
    { 
    $$ = par_num; 
    }

parameters
  : parameter
  | parameters _COMMA parameter
  {
      sub_par = 1;
  }
  ;

parameter
  : _TYPE _ID
      {
        if($1==VOID)
          err("VOID TIP ZA PARAMETRE");
        args[par_num+fun_idx*f_num]= $1;
        insert_symbol($2, PAR, $1, ++par_num, NO_ATR);
        set_atr1(fun_idx, par_num);
        set_atr2(fun_idx, f_num);
       }
  ;

body
  : _LBRACKET variable_list
      {
        if(var_num)
          code("\n\t\tSUBS\t%%15,$%d,%%15", 4*var_num);
        code("\n@%s_body:", get_name(fun_idx));
      }
    statement_list _RBRACKET
      {
        if(return_exist==0 && get_type(fun_idx)!=3)
          warning("NO RETURN IN INT/UNSIGNED FUNC");
        else 
          return_exist=0; 
      }
  ;

g_variable_list
  : /* empty */
  | g_variable_list g_variable
  ;

g_variable
  : _TYPE _ID _SEMICOLON
      {
        if(lookup_symbol($2, GVAR) == NO_INDEX){
           insert_symbol($2, GVAR, $1, NO_ATR, NO_ATR);
           code("\n%s:",$2);
           code("\n\t\tWORD 1");
           }
        else 
           err("redefinition of global '%s'", $2);
      }
  ;

variable_list
  : /* empty */
  | variable_list variable
  ;


vars
  : _ID
  {
        if(lookup_symbol($1, VAR|PAR) == NO_INDEX)
           insert_symbol($1, VAR, tip, ++var_num, NO_ATR);
        else 
           err("redefinition of '%s'", $1);
      }
  | vars _COMMA _ID 
  {
        if(lookup_symbol($3, VAR|PAR) == NO_INDEX)
           insert_symbol($3, VAR, tip, ++var_num, NO_ATR);
        else 
           err("redefinition of '%s'", $3);
      }
  ;

variable
  : _TYPE {tip=$1;} vars _SEMICOLON
  {
  if($1==VOID)
        err("VOID TIP ZA PROMENLJIVU");
  }
  ;

statement_list
  : /* empty */
  | statement_list statement
  ;

statement
  : compound_statement
  | assignment_statement
  | if_statement  
  | return_statement  {return_exist=1;}
  | inc_statement
  | oiai_statement
  | branch_statement 
  ;

branch_statement 
  : _BRANCH _LPAREN 
    { 
      $<i>$ = ++lab_num;
      code("\n@branch%d:", lab_num);
    }
    _ID
    {
      $<i>$=lookup_symbol($4, VAR);
      if($<i>$ == NO_INDEX)
        err("VARIABLE NOT DEFINED");
    }
    _SEMICOLON literal
    {
      if(get_type($<i>5)!=get_type($7))
        err("invalid operands: first branch constant");
      gen_cmp($<i>5,$7);
      code("\n\t\tJEQ\t@one%d", $<i>3);
    }
    _COMMA literal 
    {
      if(get_type($<i>5)!=get_type($10))
        err("invalid operands: second branch constant");
      gen_cmp($<i>5,$10);
      code("\n\t\tJEQ\t@two%d", $<i>3);
    }
    _COMMA literal
    {
      if(get_type($<i>5)!=get_type($13))
        err("invalid operands: third branch constant");
      gen_cmp($<i>5,$13);
      code("\n\t\tJEQ\t@three%d", $<i>3);
    } 
    _RPAREN
    {
      code("\n\t\tJMP\t@other%d", $<i>3);
    } 
    _ONE _ARROW 
    {
      code("\n@one%d:", lab_num);
    }
    statement
    {
      code("\n\t\tJMP \t@exit%d", $<i>3);
    }
    _TWO _ARROW
    {
      code("\n@two%d:", lab_num);
    }
     statement
    {
      code("\n\t\tJMP \t@exit%d", $<i>3);
    }
    _THREE _ARROW 
    {
      code("\n@three%d:", lab_num);
    }
    statement
    {
      code("\n\t\tJMP \t@exit%d", $<i>3);
    }
    _OTHER _ARROW 
    {
      code("\n@other%d:", lab_num);
    }
    statement
    {
      code("\n\t\tJMP \t@exit%d", $<i>3);
    }
    _ENDBRANCH
    {
      code("\n@exit%d:", $<i>3);
    }
  ;

oiai_statement
  : _PERCENT _OIAI _LPAREN
    {
        $<i>$ = ++lab_num;
        code("\n@oiai%d:", lab_num);
    }
    rel_exps
    {
        code("\n\t\t%s\t@exit%d", opp_jumps[$5], $<i>4);
        code("\n@true%d:", $<i>4);
    }
  _RPAREN _HANA statement _PERCENT
    {
        code("\n@exit%d:", $<i>4);
        $$ = $<i>4;
    }
  ;

inc_statement
  : _ID _INC _SEMICOLON
    {
    if(lookup_symbol($1,FUN)!=NO_INDEX)
      {
        err("%s cant be incremented(function)", $1); 
      }
      else
      {
      	int idx = lookup_symbol($1, GVAR|VAR|PAR);
        if(idx == NO_INDEX)
        err("'%s' undeclared", $1);
        code("\n\t\tADDS\t");
    	gen_sym_name(idx); 
    	code(",$1,"); 
    	gen_sym_name(idx);
      }
      }
  ;

compound_statement
  : _LBRACKET statement_list _RBRACKET
  ;

assignment_statement
  : _ID _ASSIGN num_exp _SEMICOLON
      {
        int idx = lookup_symbol($1, GVAR|VAR|PAR);
        if(idx == NO_INDEX)
          err("invalid lvalue '%s' in assignment", $1);
        else
          if(get_type(idx) != get_type($3))
            err("incompatible types in assignment");

        gen_mov($3, idx);
        for(int i=0; i<SYMBOL_TABLE_LENGTH; i++)
        {
          if(get_atr2(i)==7 && get_kind(i)!=(VAR|PAR|GVAR) && idx!=i)
          {  
            code("\n\t\tADD%s\t",get_type(i)==INT?"S":"U");
            gen_sym_name(i);
            code(",$1,");       
            gen_sym_name(i);
            free_if_reg(i);
            set_atr2(i,NO_ATR);
          }
        }
      }
  ;

num_exp
  : exp

  | num_exp _AROP exp
      {
        if(get_type($1) != get_type($3))
          err("invalid operands: arithmetic operation");
         else{
        int t1 = get_type($1);    
        code("\n\t\t%s\t", ar_instructions[$2 + (t1 - 1) * AROP_NUMBER]);
       /* if(sub_par == 1 && ar_instructions[$2 + (t1 - 1) * AROP_NUMBER]=="SUBS")
        {
        gen_sym_name($3);
        code(",");
        gen_sym_name($1);
        code(",");
        free_if_reg($1);
        free_if_reg($3);
        $$ = take_reg();
        gen_sym_name($$);
        set_type($$, t1);
        }*/
         gen_sym_name($1);
        code(",");
        gen_sym_name($3);
        code(",");
        free_if_reg($3);
        free_if_reg($1);
        $$ = take_reg();
        gen_sym_name($$);
        set_type($$, t1);
        }
      }
  ;

exp
  : literal

  | _ID
      {
        $$ = lookup_symbol($1, GVAR|VAR|PAR);
        if($$ == NO_INDEX)
          err("'%s' undeclared", $1);
      }

  | function_call
      {
        $$ = take_reg();
        gen_mov(FUN_REG, $$);
      }
  
  | _LPAREN num_exp _RPAREN
      { $$ = $2; }
  
  | _ID _INC
      {
        if(lookup_symbol($1,FUN)!=NO_INDEX)
          {
            err("%s cant be incremented(function)", $1); 
          }
        else
        {
         $$ = lookup_symbol($1, GVAR|VAR|PAR);
          if($$ == NO_INDEX)
           err("'%s' undeclared", $1);
        }
        set_atr2($$,7);
      }

  | cond_op
  ;

cond_op
  : _LPAREN rel_exps _RPAREN _QMARK cond_exp _COLON cond_exp 
      {
               
        /*int idx1 = lookup_symbol($6, GVAR|VAR|PAR|LIT);
        int idx2 = lookup_symbol($8, GVAR|VAR|PAR|LIT);
        if(idx1 == NO_INDEX)
          err("invalid lvalue '%s' in conditional op", $6);
        else 
          if(idx2 == NO_INDEX)
            err("invalid lvalue '%s' in conditional op", $8);
          else*/
        if(get_type($5) != get_type($7))
          err("incompatible types in arguments");
        $$=take_reg();
        ++lab_num;
        code("\n@cond_op%d:", lab_num); 
        code("\n\t\t%s\t@false%d", opp_jumps[$2], lab_num);
        code("\n@true%d:", lab_num);
        gen_mov($5,$$);
        code("\n\t\tJMP \t@exit%d", lab_num);
        code("\n@false%d:", lab_num);
        gen_mov($7,$$);
        code("\n@exit%d:", lab_num);

       /* printf("%d\n",$5);
        printf("%d\n",$7);
        $$= $6;*/
      }
  ;

cond_exp
  : literal
  
  | _ID 
      {
        $$ = lookup_symbol($1, GVAR|VAR|PAR);
        if($$ == NO_INDEX)
          err("'%s' undeclared", $1);
      }
  ;

literal
  : _INT_NUMBER
      { $$ = insert_literal($1, INT); }

  | _UINT_NUMBER
      { $$ = insert_literal($1, UINT); }
  ;

function_call
  : _ID 
      {
        fcall_idx = lookup_symbol($1, FUN);
        if(fcall_idx == NO_INDEX)
          err("'%s' is not a function", $1);
        fcall_ind = fcall_idx * get_atr2(fcall_idx);
      }
    _LPAREN argument_list
    {
     for(int i = arg_num-1 ; i > -1 ; i--)
        { 
           code("\n\t\tPUSH\t");
           gen_sym_name(argumenti[i]);
        }
    }
    _RPAREN
      {
       
        if(get_atr1(fcall_idx) != $4)
          err("wrong number of arguments");
        code("\n\t\tCALL\t%s", get_name(fcall_idx));
        if($4 > 0)
          code("\n\t\tADDS\t%%15,$%d,%%15", $4 * 4);
        set_type(FUN_REG, get_type(fcall_idx));
        $$ = FUN_REG;
        arg_num = 0;
      }
  ;

argument_list
  :  /* empty */
    { $$ = 0; }
  | arguments 
    { $$ = arg_num; }

arguments
  : argument
  | arguments _COMMA argument
  ;

argument
  : num_exp
    { 
      if(args[fcall_ind+arg_num]!=get_type($1))
        err("incompatible type for argument in '%s'",
            get_name(fcall_idx));
      if(lookup_symbol(get_name($1), REG|LIT|GVAR|VAR|PAR)!=-1)
      {
        argumenti[arg_num]=lookup_symbol(get_name($1), LIT|GVAR|VAR|PAR);
      }
      else
      {
        argumenti[arg_num]=$1;
      }
     /* printf("%s\n",get_name($1));
      printf("%d\n", argumenti[arg_num]);
      print_symtab(); */
      ++arg_num;
      free_if_reg($1);
    }
  ;


if_statement
  : if_part %prec ONLY_IF
      { code("\n@exit%d:", $1); }

  | if_part _ELSE statement
      { code("\n@exit%d:", $1); }
  ;

if_part
  : _IF _LPAREN
      {
        $<i>$ = ++lab_num;
        code("\n@if%d:", lab_num);
      }
    rel_exps
      { 
        if(log_exist==0)
        {
        code("\n\t\t%s\t@false%d", opp_jumps[$4], $<i>3);        
        }
        code("\n@true%d:", $<i>3);
      }
    _RPAREN statement
      {
        code("\n\t\tJMP \t@exit%d", $<i>3);
        code("\n@false%d:", $<i>3);
        $$ = $<i>3;
      }
  ;

rel_exp
  : num_exp _RELOP num_exp
      {
        if(get_type($1) != get_type($3))
          err("invalid operands: relational operator");
        $$ = $2 + ((get_type($1) - 1) * RELOP_NUMBER);
        gen_cmp($1, $3);
      }
  ;

rel_exps
  : rel_exp
  {
  log_exist=0;
  }
  | rel_exps
  {
  code("\n\t\t%s\t@false%d", opp_jumps[$1], lab_num);
  } 
   _AND 
  {
   log_exist=1;
  }
   rel_exp
  { 
  code("\n\t\t%s\t@false%d", opp_jumps[$5], lab_num);
  }
  | rel_exps
  {
  code("\n\t\t%s\t@true%d", opp1_jumps[$1], lab_num); 
  }
   _OR  
  {
  log_exist=1;
  }
   rel_exp
  {
  code("\n\t\t%s\t@true%d", opp1_jumps[$5], lab_num);
  }
  ;

return_statement
  : _RETURN num_exp _SEMICOLON
      {
        if(get_type(fun_idx) != get_type($2))
          err("incompatible types in return");
        if(get_type(fun_idx) == 3)
          err("VOID IN RETURN");
        gen_mov($2, FUN_REG);
        code("\n\t\tJMP \t@%s_exit", get_name(fun_idx));        
      }
   | _RETURN _SEMICOLON
      {
        if(get_type(fun_idx) != 3) 
          warning("RETURN WITHOUT VALUE");
      }
  ;

%%

int yyerror(char *s) {
  fprintf(stderr, "\nline %d: ERROR: %s", yylineno, s);
  error_count++;
  return 0;
}

void warning(char *s) {
  fprintf(stderr, "\nline %d: WARNING: %s", yylineno, s);
  warning_count++;
}

int main() {
  int synerr;
  init_symtab();
  output = fopen("output.asm", "w+");

  synerr = yyparse();

  clear_symtab();
  fclose(output);
  
  if(warning_count)
    printf("\n%d warning(s).\n", warning_count);

  if(error_count) {
    remove("output.asm");
    printf("\n%d error(s).\n", error_count);
  }

  if(synerr)
    return -1;  //syntax error
  else if(error_count)
    return error_count & 127; //semantic errors
  else if(warning_count)
    return (warning_count & 127) + 127; //warnings
  else
    return 0; //OK
}

