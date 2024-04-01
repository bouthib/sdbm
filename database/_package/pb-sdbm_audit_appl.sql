-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE BODY SDBM_AUDIT_APPL
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_AUDIT_APPL
  AUTEUR  : Benoit Bouthillier 2012-02-08
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des fonctions d'audit.

**********************************************************************/


   /*******************************************************************
     CONSTANTE :
    ******************************************************************/

    -- Version de l'entête PL/SQL
    VERSION_PB CONSTANT VARCHAR2(4 CHAR) := '0.01';



   /******************************************************************
     PROCEDURE : VERSION
     AUTEUR    : Benoit Bouthillier 2009-10-02
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but de retourner la version de
           de l'entête PL/SQL et du code de ce package Oracle.
   
           Particularité:
              SERVEROUTPUT doit être activé

     PARAMETRES: N/A

   *******************************************************************/
   PROCEDURE VERSION
   IS

   BEGIN

      DBMS_OUTPUT.PUT_LINE('Version');
      DBMS_OUTPUT.PUT_LINE('----------------------------');

      -- Affichage de la version de l'entête PL/SQL (PS)
      DBMS_OUTPUT.PUT_LINE('Package Specification : ' || VERSION_PS);

      -- Affichage de la version du code PL/SQL (PB)
      DBMS_OUTPUT.PUT_LINE('Package Body          : ' || VERSION_PB);

   END VERSION;


   /******************************************************************
     PROCEDURE : GENERER_TRIGGER
     AUTEUR    : Benoit Bouthillier 2012-02-08
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but de générer et de faire la
           création des triggers requis pour l'audit.
   
           Particularité:
              SERVEROUTPUT peut être activé

     PARAMETRES:  Nom de la table     (A_NOM_TABLE)
                  Liste des colonnes  (A_LISTE_COLONNE)
                  Exécution           (A_EXECUTION)
   *******************************************************************/
   PROCEDURE GENERER_TRIGGER
   (
      A_NOM_TABLE     VARCHAR2                -- Nom de table
     ,A_LISTE_COLONNE VARCHAR2                -- Liste des colonnes (format : '''COL1'',''COL2''' ou si le contenu de la colonne est sensible : '''COL2:H''')
     ,A_EXECUTION     BOOLEAN   DEFAULT TRUE  -- Exécution de la commande de création des triggers
   )
   IS

      C_TRIGGER_BODY_DEB VARCHAR2(750 CHAR) :=
      'CREATE OR REPLACE TRIGGER TR_AUD_[ALIAS_TABLE]'                                                                                                                                  || CHR(10) ||
      ''                                                                                                                                                                                || CHR(10) ||
      '/******************************************************************'                                                                                                             || CHR(10) ||
      '  TRIGGER : TR_AUD_[ALIAS_TABLE]'                                                                                                                                                || CHR(10) ||
      '  AUTEUR  : Benoit Bouthillier 2012-01-26'                                                                                                                                       || CHR(10) ||
      '            (génération automatique via SDBM_AUDIT_APPL)'                                                                                                                        || CHR(10) ||
      ' ------------------------------------------------------------------'                                                                                                             || CHR(10) ||
      '  BUT : Audit applicative'                                                                                                                                                       || CHR(10) ||
      ''                                                                                                                                                                                || CHR(10) ||
      '*******************************************************************/'                                                                                                            || CHR(10) ||
      ''                                                                                                                                                                                || CHR(10) ||
      '   BEFORE INSERT OR UPDATE OR DELETE'                                                                                                                                            || CHR(10) ||
      '   ON [TABLE]'                                                                                                                                                                   || CHR(10) ||
      '   FOR EACH ROW'                                                                                                                                                                 || CHR(10) ||
      ''                                                                                                                                                                                || CHR(10) ||
      'BEGIN'                                                                                                                                                                           || CHR(10) ||
      ''                                                                                                                                                                                || CHR(10) ;

      C_TRIGGER_BODY_COL VARCHAR2(750 CHAR) :=
      '   IF (INSERTING) THEN'                                                                                                                                                          || CHR(10) ||
      '      SDBM_AUDIT_APPL.INSERER_AUDIT(''I'',''[TABLE]'',''[COLONNE]'',[IDENTIFIANT_N],NULL,:NEW.[COLONNE]);'                                                                       || CHR(10) ||
      '   ELSIF (UPDATING) THEN'                                                                                                                                                        || CHR(10) ||
      '      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.[COLONNE],:NEW.[COLONNE])) THEN'                                                                                                  || CHR(10) ||
      '         SDBM_AUDIT_APPL.INSERER_AUDIT(''U'',''[TABLE]'',''[COLONNE]'',[IDENTIFIANT_O],:OLD.[COLONNE],:NEW.[COLONNE]);'                                                          || CHR(10) ||
      '      END IF;'                                                                                                                                                                   || CHR(10) ||
      '   ELSE'                                                                                                                                                                         || CHR(10) ||
      '      SDBM_AUDIT_APPL.INSERER_AUDIT(''D'',''[TABLE]'',''[COLONNE]'',[IDENTIFIANT_O],:OLD.[COLONNE],NULL);'                                                                       || CHR(10) ||
      '   END IF;'                                                                                                                                                                      || CHR(10) ||
      ''                                                                                                                                                                                || CHR(10) ;

      C_TRIGGER_BODY_COS VARCHAR2(750 CHAR) :=
      '   IF (INSERTING) THEN'                                                                                                                                                          || CHR(10) ||
      '      SDBM_AUDIT_APPL.INSERER_AUDIT(''I'',''[TABLE]'',''[COLONNE]'',[IDENTIFIANT_N],NULL,RPAD(''*'',LENGTH(:NEW.[COLONNE])-1,''*''));'                                           || CHR(10) ||
      '   ELSIF (UPDATING) THEN'                                                                                                                                                        || CHR(10) ||
      '      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.[COLONNE],:NEW.[COLONNE])) THEN'                                                                                                  || CHR(10) ||
      '         SDBM_AUDIT_APPL.INSERER_AUDIT(''U'',''[TABLE]'',''[COLONNE]'',[IDENTIFIANT_O],RPAD(''*'',LENGTH(:OLD.[COLONNE])-1,''*''),RPAD(''*'',LENGTH(:NEW.[COLONNE])-1,''*''));'  || CHR(10) ||
      '      END IF;'                                                                                                                                                                   || CHR(10) ||
      '   ELSE'                                                                                                                                                                         || CHR(10) ||
      '      SDBM_AUDIT_APPL.INSERER_AUDIT(''D'',''[TABLE]'',''[COLONNE]'',[IDENTIFIANT_O],RPAD(''*'',LENGTH(:OLD.[COLONNE])-1,''*''),NULL);'                                           || CHR(10) ||
      '   END IF;'                                                                                                                                                                      || CHR(10) ||
      ''                                                                                                                                                                                || CHR(10) ;

      C_TRIGGER_BODY_FIN VARCHAR2(50 CHAR) :=
      'END TR_AUD_[ALIAS_TABLE];';

      -- Recherche des identifiant d'une table (clé primaire)
      CURSOR C_CLE_PRIMAIRE IS
         SELECT IND.COLUMN_NAME
           FROM USER_CONSTRAINTS CON
               ,USER_IND_COLUMNS IND
          WHERE CON.TABLE_NAME      = A_NOM_TABLE
            AND CON.CONSTRAINT_TYPE = 'P'
            AND CON.INDEX_NAME      = IND.INDEX_NAME
          ORDER BY COLUMN_POSITION;

      TYPE T_RC_INFO IS REF CURSOR;

      -- Curseur dynamique de retour d'information
      VC_INFO          T_RC_INFO;
      V_COLUMN_NAME    USER_TAB_COLUMNS.COLUMN_NAME%TYPE;

      V_ALIAS_TABLE    VARCHAR2(30 CHAR);
      V_IND_ALIAS      NUMBER  := 0;
      V_NB_ALIAS_EX    NUMBER  := 1;

      V_LISTE_COLONNE  VARCHAR2(1024 CHAR) := REPLACE(A_LISTE_COLONNE,':H','');
      V_IDENTIFIANT_O  VARCHAR2(1000 CHAR);
      V_IDENTIFIANT_N  VARCHAR2(1000 CHAR);
      V_SQL_TRIGGER    VARCHAR2(32767 CHAR);
      V_NB_COLONNE     NUMBER := 0;

   BEGIN

      -- Génération de l'alias de la table
      WHILE (V_NB_ALIAS_EX = 1) LOOP

         V_ALIAS_TABLE := SUBSTR(A_NOM_TABLE,1,20) || '_' || TO_CHAR(V_IND_ALIAS,'FM00');

         SELECT COUNT(1)
           INTO V_NB_ALIAS_EX
           FROM USER_OBJECTS
          WHERE OBJECT_NAME = V_ALIAS_TABLE;

         V_IND_ALIAS := V_IND_ALIAS + 1;

      END LOOP;


      -- Recherche de l'identifiant
      FOR RC_CLE_PRIMAIRE IN C_CLE_PRIMAIRE LOOP
         V_IDENTIFIANT_O := V_IDENTIFIANT_O || '''|' || RC_CLE_PRIMAIRE.COLUMN_NAME || ':'' || NVL(TO_CHAR(:OLD.' || RC_CLE_PRIMAIRE.COLUMN_NAME || '),''NULL'') || ';
         V_IDENTIFIANT_N := V_IDENTIFIANT_N || '''|' || RC_CLE_PRIMAIRE.COLUMN_NAME || ':'' || NVL(TO_CHAR(:NEW.' || RC_CLE_PRIMAIRE.COLUMN_NAME || '),''NULL'') || ';
      END LOOP;

      IF (V_IDENTIFIANT_O IS NULL) THEN

         -- Absence de clé primaire
         V_IDENTIFIANT_O := '''ROWID: '' || NVL(TO_CHAR(:OLD.ROWID),''NULL'')';
         V_IDENTIFIANT_N := '''ROWID: N/A''';

      ELSE

         -- Ajustement du début de la chaine
         V_IDENTIFIANT_O := '''' || SUBSTR(V_IDENTIFIANT_O,3);
         V_IDENTIFIANT_N := '''' || SUBSTR(V_IDENTIFIANT_N,3);

         -- Ajustement de la fin de la chaine
         V_IDENTIFIANT_O := SUBSTR(V_IDENTIFIANT_O,1,LENGTH(V_IDENTIFIANT_O)-4);
         V_IDENTIFIANT_N := SUBSTR(V_IDENTIFIANT_N,1,LENGTH(V_IDENTIFIANT_N)-4);

      END IF;


      -- Ajout de l'entête du trigger
      V_SQL_TRIGGER := REPLACE(C_TRIGGER_BODY_DEB,'[ALIAS_TABLE]',V_ALIAS_TABLE);
      V_SQL_TRIGGER := REPLACE(V_SQL_TRIGGER,'[TABLE]',A_NOM_TABLE);

      OPEN VC_INFO FOR 'SELECT COLUMN_NAME'
                    || '  FROM USER_TAB_COLUMNS'
                    || ' WHERE TABLE_NAME  = ''' || A_NOM_TABLE || ''''
                    || '   AND COLUMN_NAME IN (' || V_LISTE_COLONNE || ')'
                    || ' ORDER BY COLUMN_ID';

      LOOP

         FETCH VC_INFO
          INTO V_COLUMN_NAME;
       
         EXIT WHEN VC_INFO%NOTFOUND;

         IF (INSTR(A_LISTE_COLONNE,'''' || V_COLUMN_NAME || ':H''') = 0) THEN
            V_SQL_TRIGGER := V_SQL_TRIGGER || REPLACE(REPLACE(REPLACE(REPLACE(C_TRIGGER_BODY_COL,'[TABLE]',A_NOM_TABLE),'[COLONNE]',V_COLUMN_NAME),'[IDENTIFIANT_O]',V_IDENTIFIANT_O),'[IDENTIFIANT_N]',V_IDENTIFIANT_N);
         ELSE
            V_SQL_TRIGGER := V_SQL_TRIGGER || REPLACE(REPLACE(REPLACE(REPLACE(C_TRIGGER_BODY_COS,'[TABLE]',A_NOM_TABLE),'[COLONNE]',V_COLUMN_NAME),'[IDENTIFIANT_O]',V_IDENTIFIANT_O),'[IDENTIFIANT_N]',V_IDENTIFIANT_N);
         END IF;
         V_NB_COLONNE := V_NB_COLONNE + 1;

      END LOOP;
      CLOSE VC_INFO;

      -- Ajout de la fin du trigger
      V_SQL_TRIGGER := V_SQL_TRIGGER || REPLACE(C_TRIGGER_BODY_FIN,'[ALIAS_TABLE]',V_ALIAS_TABLE);

      IF (V_NB_COLONNE < (LENGTH(V_LISTE_COLONNE) - LENGTH(REPLACE(V_LISTE_COLONNE,',')) + 1)) THEN

         RAISE_APPLICATION_ERROR(-20000,'Le nombre de colonne trouvé (' || V_NB_COLONNE || ') ne correspond pas à la liste reçu.');

      END IF;

      -- Affichage du la commande qui sera exécuté 
      DBMS_OUTPUT.PUT_LINE(V_SQL_TRIGGER);

      -- Exécution
      IF (A_EXECUTION) THEN
         EXECUTE IMMEDIATE V_SQL_TRIGGER;
      END IF;

   END GENERER_TRIGGER;


   /******************************************************************
     FONCTION : VALEUR_MODIFIEE
     AUTEUR   : Benoit Bouthillier 2012-02-02
    ------------------------------------------------------------------
     BUT : Cette fonction permet de faire la vérification si une
           valeur à été modifiée.
   
     PARAMETRES:  Ancienne valeur  (A_ANCI_VALEUR)
                  Nouvelle valeur  (A_NOUV_VALEUR)
   *******************************************************************/
   FUNCTION VALEUR_MODIFIEE
   (
      A_ANCI_VALEUR AUDIT_APPL.ANCI_VALEUR%TYPE  -- Ancienne valeur
     ,A_NOUV_VALEUR AUDIT_APPL.NOUV_VALEUR%TYPE  -- Nouvelle valeur
   )
   RETURN BOOLEAN
   IS

   BEGIN

      IF (
               (A_ANCI_VALEUR IS NULL AND A_NOUV_VALEUR IS NOT NULL)
            OR (A_NOUV_VALEUR IS NULL AND A_ANCI_VALEUR IS NOT NULL)
            OR (A_ANCI_VALEUR         !=  A_NOUV_VALEUR)
         ) THEN

         RETURN TRUE;

      ELSE

         RETURN FALSE;

      END IF;

   END VALEUR_MODIFIEE;


   /******************************************************************
     PROCEDURE : INSERER_AUDIT
     AUTEUR    : Benoit Bouthillier 2012-02-02
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but de faire l'insertion dans la
           table d'audit.
   
   *******************************************************************/
   PROCEDURE INSERER_AUDIT
   (
      A_TYPE_DML    CHAR                                                         -- Type de DML
     ,A_NOM_TABLE   AUDIT_APPL.NOM_TABLE%TYPE                                    -- Nom de la table
     ,A_NOM_COLONNE AUDIT_APPL.NOM_COLONNE%TYPE                                  -- Nom de la colonne
     ,A_IDENTIFIANT AUDIT_APPL.IDENTIFIANT%TYPE                                  -- Identifiant
     ,A_ANCI_VALEUR AUDIT_APPL.ANCI_VALEUR%TYPE                                  -- Ancienne valeur
     ,A_NOUV_VALEUR AUDIT_APPL.NOUV_VALEUR%TYPE                                  -- Nouvelle valeur
     ,A_USAGER      AUDIT_APPL.NOM_USAGER%TYPE  DEFAULT NVL(V('APP_USER'),USER)  -- Usager
   )
   IS

   BEGIN

      INSERT INTO AUDIT_APPL
      (
         NOM_USAGER
        ,NOM_TABLE
        ,NOM_COLONNE
        ,TYPE_DML
        ,IDENTIFIANT
        ,ANCI_VALEUR
        ,NOUV_VALEUR
      )
      VALUES
      (
         SUBSTR(A_USAGER,1,30)
        ,SUBSTR(A_NOM_TABLE,1,30)
        ,SUBSTR(A_NOM_COLONNE,1,30)
        ,SUBSTR(A_TYPE_DML,1,1)
        ,SUBSTR(A_IDENTIFIANT,1,200)
        ,SUBSTR(A_ANCI_VALEUR,1,4000)
        ,SUBSTR(A_NOUV_VALEUR,1,4000)
      );

   END INSERER_AUDIT;

END SDBM_AUDIT_APPL;
/

