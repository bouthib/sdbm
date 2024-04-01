-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


WHENEVER OSERROR  EXIT 8
WHENEVER SQLERROR EXIT SQL.SQLCODE


CONNECT / as sysdba
alter session set container = XEPDB1;
alter session set current_schema = SDBM;


SET SERVEROUTPUT ON
BEGIN

/*
select ut.table_name
      ,'''''' || uc.column_name || ''''''
  from user_tables      ut
      ,user_tab_columns uc
 where ut.table_name = uc.table_name
   and ut.table_name not in ('AUDIT_APPL','EVENEMENT_DEFAUT_TRADUCTION','NOTIF_DIF','JOURNAL')
   and ut.table_name not like 'CD_%'
   and ut.table_name not like 'MV_%'
   and ut.table_name not like 'HIST_%'
   and ut.table_name not like 'INFO_%'
order by ut.table_name, uc.column_id;

TABLE_NAME                     ''''''||UC.COLUMN_NAME||''''''   
------------------------------ ----------------------------------
CIBLE                          ''TYPE_CIBLE''                     
CIBLE                          ''SOUS_TYPE_CIBLE''                
CIBLE                          ''NOM_CIBLE''                      
CIBLE                          ''NOM_USAGER''                     
CIBLE                          ''MDP_USAGER''                     
CIBLE                          ''TYPE_CONNEXION''                 
CIBLE                          ''CONNEXION''                      
CIBLE                          ''STARTUP_TIME''                   
CIBLE                          ''DH_MAJ_STATUT''                  
CIBLE                          ''STATUT''                         
CIBLE                          ''NOTIF_EFFECT''                   
CIBLE                          ''NOTIFICATION''                   
CIBLE                          ''DESTI_NOTIF''                    
CIBLE                          ''SQL_HORAIRE''                    
CIBLE                          ''DH_DERN_VERIF''                  
CIBLE                          ''DH_PROCHAINE_VERIF''             
CIBLE                          ''INTERVAL''                       
CIBLE                          ''NOM_SERVEUR''                    
CIBLE                          ''NOM_INSTANCE''                   
CIBLE                          ''VERSION''                        
CIBLE                          ''FICHIER_ALERTE''                 
CIBLE                          ''TYPE_BD''                        
CIBLE                          ''TYPE_CIBLE_REF''                 
CIBLE                          ''NOM_CIBLE_REF''                  
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('CIBLE','''TYPE_CIBLE'',''SOUS_TYPE_CIBLE'',''NOM_CIBLE'',''NOM_USAGER'',''MDP_USAGER:H'',''TYPE_CONNEXION'',''CONNEXION'',''NOTIFICATION'',''DESTI_NOTIF'',''SQL_HORAIRE'',''INTERVAL'',''TYPE_BD'',''TYPE_CIBLE_REF'',''NOM_CIBLE_REF''',FALSE);
   
END;
/


CREATE OR REPLACE TRIGGER TR_AUD_CIBLE_00

/******************************************************************
  TRIGGER : TR_AUD_CIBLE_00
  AUTEUR  : Benoit Bouthillier 2012-01-26
            (génération automatique via SDBM_AUDIT_APPL)

            +

            Condition supplémentaire :
            IF ((:NEW.MDP_USAGER IS NOT NULL)...
 ------------------------------------------------------------------
  BUT : Audit applicative

*******************************************************************/

   BEFORE INSERT OR UPDATE OR DELETE
   ON CIBLE
   FOR EACH ROW

BEGIN

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','TYPE_CIBLE','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.TYPE_CIBLE);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.TYPE_CIBLE,:NEW.TYPE_CIBLE)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','TYPE_CIBLE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.TYPE_CIBLE,:NEW.TYPE_CIBLE);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','TYPE_CIBLE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.TYPE_CIBLE,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','SOUS_TYPE_CIBLE','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.SOUS_TYPE_CIBLE);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.SOUS_TYPE_CIBLE,:NEW.SOUS_TYPE_CIBLE)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','SOUS_TYPE_CIBLE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.SOUS_TYPE_CIBLE,:NEW.SOUS_TYPE_CIBLE);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','SOUS_TYPE_CIBLE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.SOUS_TYPE_CIBLE,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','NOM_CIBLE','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.NOM_CIBLE);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.NOM_CIBLE,:NEW.NOM_CIBLE)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','NOM_CIBLE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.NOM_CIBLE,:NEW.NOM_CIBLE);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','NOM_CIBLE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.NOM_CIBLE,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','NOM_USAGER','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.NOM_USAGER);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.NOM_USAGER,:NEW.NOM_USAGER)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','NOM_USAGER','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.NOM_USAGER,:NEW.NOM_USAGER);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','NOM_USAGER','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.NOM_USAGER,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','MDP_USAGER','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,RPAD('*',LENGTH(:NEW.MDP_USAGER)-1,'*'));
   ELSIF (UPDATING) THEN
      IF ((:NEW.MDP_USAGER IS NOT NULL) AND (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.MDP_USAGER,:NEW.MDP_USAGER))) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','MDP_USAGER','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),RPAD('*',LENGTH(:OLD.MDP_USAGER)-1,'*'),RPAD('*',LENGTH(:NEW.MDP_USAGER)-1,'*'));
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','MDP_USAGER','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),RPAD('*',LENGTH(:OLD.MDP_USAGER)-1,'*'),NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','TYPE_CONNEXION','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.TYPE_CONNEXION);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.TYPE_CONNEXION,:NEW.TYPE_CONNEXION)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','TYPE_CONNEXION','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.TYPE_CONNEXION,:NEW.TYPE_CONNEXION);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','TYPE_CONNEXION','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.TYPE_CONNEXION,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','CONNEXION','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.CONNEXION);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.CONNEXION,:NEW.CONNEXION)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','CONNEXION','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.CONNEXION,:NEW.CONNEXION);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','CONNEXION','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.CONNEXION,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','NOTIFICATION','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.NOTIFICATION);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.NOTIFICATION,:NEW.NOTIFICATION)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','NOTIFICATION','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.NOTIFICATION,:NEW.NOTIFICATION);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','NOTIFICATION','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.NOTIFICATION,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','DESTI_NOTIF','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.DESTI_NOTIF);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.DESTI_NOTIF,:NEW.DESTI_NOTIF)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','DESTI_NOTIF','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.DESTI_NOTIF,:NEW.DESTI_NOTIF);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','DESTI_NOTIF','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.DESTI_NOTIF,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','SQL_HORAIRE','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.SQL_HORAIRE);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.SQL_HORAIRE,:NEW.SQL_HORAIRE)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','SQL_HORAIRE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.SQL_HORAIRE,:NEW.SQL_HORAIRE);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','SQL_HORAIRE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.SQL_HORAIRE,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','INTERVAL','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.INTERVAL);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.INTERVAL,:NEW.INTERVAL)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','INTERVAL','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.INTERVAL,:NEW.INTERVAL);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','INTERVAL','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.INTERVAL,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','TYPE_BD','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.TYPE_BD);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.TYPE_BD,:NEW.TYPE_BD)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','TYPE_BD','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.TYPE_BD,:NEW.TYPE_BD);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','TYPE_BD','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.TYPE_BD,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','TYPE_CIBLE_REF','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.TYPE_CIBLE_REF);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.TYPE_CIBLE_REF,:NEW.TYPE_CIBLE_REF)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','TYPE_CIBLE_REF','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.TYPE_CIBLE_REF,:NEW.TYPE_CIBLE_REF);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','TYPE_CIBLE_REF','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.TYPE_CIBLE_REF,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','NOM_CIBLE_REF','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.NOM_CIBLE_REF);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.NOM_CIBLE_REF,:NEW.NOM_CIBLE_REF)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','NOM_CIBLE_REF','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.NOM_CIBLE_REF,:NEW.NOM_CIBLE_REF);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','NOM_CIBLE_REF','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.NOM_CIBLE_REF,NULL);
   END IF;

   IF (INSERTING) THEN
      SDBM_AUDIT_APPL.INSERER_AUDIT('I','CIBLE','COMMENTAIRE','TYPE_CIBLE:' || NVL(TO_CHAR(:NEW.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:NEW.NOM_CIBLE),'NULL'),NULL,:NEW.COMMENTAIRE);
   ELSIF (UPDATING) THEN
      IF (SDBM_AUDIT_APPL.VALEUR_MODIFIEE(:OLD.COMMENTAIRE,:NEW.COMMENTAIRE)) THEN
         SDBM_AUDIT_APPL.INSERER_AUDIT('U','CIBLE','COMMENTAIRE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.COMMENTAIRE,:NEW.COMMENTAIRE);
      END IF;
   ELSE
      SDBM_AUDIT_APPL.INSERER_AUDIT('D','CIBLE','COMMENTAIRE','TYPE_CIBLE:' || NVL(TO_CHAR(:OLD.TYPE_CIBLE),'NULL') || '|NOM_CIBLE:' || NVL(TO_CHAR(:OLD.NOM_CIBLE),'NULL'),:OLD.COMMENTAIRE,NULL);
   END IF;

END TR_AUD_CIBLE_00;
/


SET SERVEROUTPUT OFF
BEGIN

/*
DEFAUT                         ''CLE''                            
DEFAUT                         ''VALEUR''                         
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('DEFAUT','''CLE'',''VALEUR''');


/*
DESTI_NOTIF                    ''DESTI_NOTIF''                    
DESTI_NOTIF                    ''SQL_HORAIRE''                    
DESTI_NOTIF                    ''COMMENTAIRE''                    
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('DESTI_NOTIF','''DESTI_NOTIF'',''SQL_HORAIRE'',''COMMENTAIRE''');


/*
DESTI_NOTIF_DETAIL             ''DESTI_NOTIF''                    
DESTI_NOTIF_DETAIL             ''TYPE_NOTIF''                     
DESTI_NOTIF_DETAIL             ''ADRESSE''                        
DESTI_NOTIF_DETAIL             ''RETRAIT_ACCENT''                 
DESTI_NOTIF_DETAIL             ''SUPPORT_FICHIER''                
DESTI_NOTIF_DETAIL             ''SQL_HORAIRE''                    
DESTI_NOTIF_DETAIL             ''FORMULE_NOTIF_DIF''              
DESTI_NOTIF_DETAIL             ''COMMENTAIRE''                    
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('DESTI_NOTIF_DETAIL','''DESTI_NOTIF'',''TYPE_NOTIF'',''ADRESSE'',''RETRAIT_ACCENT'',''SUPPORT_FICHIER'',''SQL_HORAIRE'',''FORMULE_NOTIF_DIF'',''COMMENTAIRE''');


/*
DESTI_NOTIF_SURCHARGE_MESSAGE  ''TYPE_CIBLE''                     
DESTI_NOTIF_SURCHARGE_MESSAGE  ''SOUS_TYPE_CIBLE''                
DESTI_NOTIF_SURCHARGE_MESSAGE  ''NOM_EVENEMENT''                  
DESTI_NOTIF_SURCHARGE_MESSAGE  ''SEQ_SURCHARGE''                  
DESTI_NOTIF_SURCHARGE_MESSAGE  ''DESC_SURCHARGE''                 
DESTI_NOTIF_SURCHARGE_MESSAGE  ''MESSAGE''                        
DESTI_NOTIF_SURCHARGE_MESSAGE  ''DESTI_NOTIF''                    
DESTI_NOTIF_SURCHARGE_MESSAGE  ''COMMENTAIRE''                    
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('DESTI_NOTIF_SURCHARGE_MESSAGE','''TYPE_CIBLE'',''SOUS_TYPE_CIBLE'',''NOM_EVENEMENT'',''SEQ_SURCHARGE'',''DESC_SURCHARGE'',''MESSAGE'',''DESTI_NOTIF'',''COMMENTAIRE''');


/*
EVENEMENT                      ''TYPE_CIBLE''                     
EVENEMENT                      ''SOUS_TYPE_CIBLE''                
EVENEMENT                      ''NOM_EVENEMENT''                  
EVENEMENT                      ''TYPE_EVENEMENT''                 
EVENEMENT                      ''TYPE_FERMETURE''                 
EVENEMENT                      ''COMMANDE''                       
EVENEMENT                      ''INTERVAL_DEFAUT''                
EVENEMENT                      ''DESTI_NOTIF_DEFAUT''             
EVENEMENT                      ''DELAI_MAX_EXEC_SEC''             
EVENEMENT                      ''COMMENTAIRE''                    
EVENEMENT                      ''VISIBLE''                        
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('EVENEMENT','''TYPE_CIBLE'',''SOUS_TYPE_CIBLE'',''NOM_EVENEMENT'',''TYPE_EVENEMENT'',''TYPE_FERMETURE'',''COMMANDE'',''INTERVAL_DEFAUT'',''DESTI_NOTIF_DEFAUT'',''DELAI_MAX_EXEC_SEC'',''COMMENTAIRE'',''VISIBLE''');


/*
EVENEMENT_CIBLE                ''TYPE_CIBLE''                     
EVENEMENT_CIBLE                ''SOUS_TYPE_CIBLE''                
EVENEMENT_CIBLE                ''NOM_CIBLE''                      
EVENEMENT_CIBLE                ''NOM_EVENEMENT''                  
EVENEMENT_CIBLE                ''VERIFICATION''                   
EVENEMENT_CIBLE                ''DH_PROCHAINE_VERIF''             
EVENEMENT_CIBLE                ''DH_LOC_DERN_VERIF''              
EVENEMENT_CIBLE                ''TS_UTC_DERN_VERIF''              
EVENEMENT_CIBLE                ''INTERVAL''                       
EVENEMENT_CIBLE                ''DESTI_NOTIF''                    
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('EVENEMENT_CIBLE','''TYPE_CIBLE'',''SOUS_TYPE_CIBLE'',''NOM_CIBLE'',''NOM_EVENEMENT'',''VERIFICATION'',''INTERVAL'',''DESTI_NOTIF''');


/*
PARAMETRE                      ''CLE''                            
PARAMETRE                      ''STATUT_SERVEUR''                 
PARAMETRE                      ''FREQU_VERIF_CIBLE_SEC''          
PARAMETRE                      ''DELAI_MAX_CONNEXION_SEC''        
PARAMETRE                      ''DELAI_EPURATION_JOURNAL''        
PARAMETRE                      ''NIVEAU_JOURNAL_SERVEUR''         
PARAMETRE                      ''GARANTIE_NOTIF_SERVEUR''         
PARAMETRE                      ''LIMITE_NOTIF_CYCLE_SERVEUR''     
PARAMETRE                      ''STATUT_AGENT''                   
PARAMETRE                      ''FREQU_VERIF_AGENT''              
PARAMETRE                      ''FREQU_VERIF_AGENT_TACHE''        
PARAMETRE                      ''RETARD_MAX_SOUMISSION_TACHE''    
PARAMETRE                      ''DELAI_EPURATION_LOG_BD_TACHE''   
PARAMETRE                      ''DELAI_EPURATION_LOG_FIC_TACHE''  
PARAMETRE                      ''LIMITE_NOTIF_CYCLE_AGENT''       
PARAMETRE                      ''DELAI_EPURATION_COLLECTE''       
PARAMETRE                      ''STATUT_COLLECTE''                
PARAMETRE                      ''DELAI_AJUSTEMENT_DST_SEC''       
PARAMETRE                      ''FUSEAU_HOR_DERN_EXEC''           
PARAMETRE                      ''SERVEUR_SMTP''                   
PARAMETRE                      ''PORT_SMTP''                      
PARAMETRE                      ''NOM_USAGER_SMTP''                
PARAMETRE                      ''MDP_USAGER_SMTP''                
PARAMETRE                      ''EXPEDITEUR_SMTP''                
PARAMETRE                      ''ADRESSE_PROXY_HTTP''             
PARAMETRE                      ''LANGUE''                         
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('PARAMETRE','''CLE'',''STATUT_SERVEUR'',''FREQU_VERIF_CIBLE_SEC'',''DELAI_MAX_CONNEXION_SEC'',''DELAI_EPURATION_JOURNAL'',''NIVEAU_JOURNAL_SERVEUR'',''GARANTIE_NOTIF_SERVEUR'',''LIMITE_NOTIF_CYCLE_SERVEUR'',''STATUT_AGENT'',''FREQU_VERIF_AGENT'',''FREQU_VERIF_AGENT_TACHE'',''RETARD_MAX_SOUMISSION_TACHE'',''DELAI_EPURATION_LOG_BD_TACHE'',''DELAI_EPURATION_LOG_FIC_TACHE'',''LIMITE_NOTIF_CYCLE_AGENT'',''DELAI_EPURATION_COLLECTE'',''STATUT_COLLECTE'',''DELAI_AJUSTEMENT_DST_SEC'',''SERVEUR_SMTP'',''PORT_SMTP'',''NOM_USAGER_SMTP'',''MDP_USAGER_SMTP:H'',''EXPEDITEUR_SMTP'',''ADRESSE_PROXY_HTTP'',''LANGUE''');


/*
PARAMETRE_NOTIF_EXT            ''TYPE_NOTIF''                     
PARAMETRE_NOTIF_EXT            ''SIGNATURE_FONCTION''             
PARAMETRE_NOTIF_EXT            ''COMMENTAIRE''                    
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('PARAMETRE_NOTIF_EXT','''TYPE_NOTIF'',''SIGNATURE_FONCTION'',''COMMENTAIRE''');


/*
REPARATION                     ''TYPE_CIBLE''                     
REPARATION                     ''SOUS_TYPE_CIBLE''                
REPARATION                     ''NOM_EVENEMENT''                  
REPARATION                     ''NOM_REPARATION''                 
REPARATION                     ''COMMANDE''                       
REPARATION                     ''COMMENTAIRE''                    
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('REPARATION','''TYPE_CIBLE'',''SOUS_TYPE_CIBLE'',''NOM_EVENEMENT'',''NOM_REPARATION'',''COMMANDE'',''COMMENTAIRE''');


/*
REPARATION_EVEN_CIBLE          ''TYPE_CIBLE''                     
REPARATION_EVEN_CIBLE          ''SOUS_TYPE_CIBLE''                
REPARATION_EVEN_CIBLE          ''NOM_CIBLE''                      
REPARATION_EVEN_CIBLE          ''NOM_EVENEMENT''                  
REPARATION_EVEN_CIBLE          ''NOM_REPARATION''                 
REPARATION_EVEN_CIBLE          ''STATUT''                         
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('REPARATION_EVEN_CIBLE','''TYPE_CIBLE'',''SOUS_TYPE_CIBLE'',''NOM_CIBLE'',''NOM_EVENEMENT'',''NOM_REPARATION'',''STATUT''');


/*
TACHE_AGT                      ''NOM_SERVEUR''                    
TACHE_AGT                      ''NOM_TACHE''                      
TACHE_AGT                      ''EXECUTABLE''                     
TACHE_AGT                      ''PARAMETRE''                      
TACHE_AGT                      ''REPERTOIRE''                     
TACHE_AGT                      ''REPERTOIRE_JOURNAL''             
TACHE_AGT                      ''EXECUTION''                      
TACHE_AGT                      ''TYPE_NOTIF''                     
TACHE_AGT                      ''TYPE_NOTIF_JOURNAL''             
TACHE_AGT                      ''DESTI_NOTIF''                    
TACHE_AGT                      ''INTERVAL''                       
TACHE_AGT                      ''DELAI_AVERTISSEMENT''            
TACHE_AGT                      ''DH_PROCHAINE_EXEC''              
TACHE_AGT                      ''CODE_RETOUR_SUCCES''             
TACHE_AGT                      ''COMMENTAIRE''                    
TACHE_AGT                      ''TYPE_NOTIF_OPT''                 
TACHE_AGT                      ''TYPE_NOTIF_JOURNAL_OPT''         
TACHE_AGT                      ''DESTI_NOTIF_OPT''                
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('TACHE_AGT','''NOM_SERVEUR'',''NOM_TACHE'',''EXECUTABLE'',''PARAMETRE'',''REPERTOIRE'',''REPERTOIRE_JOURNAL'',''EXECUTION'',''TYPE_NOTIF'',''TYPE_NOTIF_JOURNAL'',''DESTI_NOTIF'',''INTERVAL'',''DELAI_AVERTISSEMENT'',''CODE_RETOUR_SUCCES'',''COMMENTAIRE'',''TYPE_NOTIF_OPT'',''TYPE_NOTIF_JOURNAL_OPT'',''DESTI_NOTIF_OPT''');


/*
TACHE_DET_MSG_AGT              ''NOM_SERVEUR''                    
TACHE_DET_MSG_AGT              ''NOM_TACHE''                      
TACHE_DET_MSG_AGT              ''TYPE_MSG''                       
TACHE_DET_MSG_AGT              ''MSG''                            
TACHE_DET_MSG_AGT              ''COMMENTAIRE''                    
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('TACHE_DET_MSG_AGT','''NOM_SERVEUR'',''NOM_TACHE'',''TYPE_MSG'',''MSG'',''COMMENTAIRE''');


/*
USAGER                         ''NOM_USAGER''                     
USAGER                         ''MOT_PASSE''                      
USAGER                         ''NOM_COMPLET''                    
USAGER                         ''COMMENTAIRE''                    
USAGER                         ''NIVEAU_SEC''                     
USAGER                         ''DH_CREATION''                    
USAGER                         ''USAGER_CREATION''                
USAGER                         ''DH_DERN_MODIF''                  
USAGER                         ''USAGER_DERN_MODIF''              
USAGER                         ''DH_DERN_CONNEXION''              
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('USAGER','''NOM_USAGER'',''MOT_PASSE:H'',''NOM_COMPLET'',''COMMENTAIRE'',''NIVEAU_SEC'',''DH_CREATION'',''USAGER_CREATION'',''DH_DERN_MODIF'',''USAGER_DERN_MODIF'',''DH_DERN_CONNEXION''');


/*
VOLUME_PHY                     ''ID_VOLUME_PHY''                  
VOLUME_PHY                     ''DESC_VOLUME_PHY''                
VOLUME_PHY                     ''TOTAL_MB''                       
VOLUME_PHY                     ''MAJ_CD_AUTORISE''            
VOLUME_PHY                     ''CHEMIN_ACCES_DEFAUT''            
VOLUME_PHY                     ''STATUT''                         
VOLUME_PHY                     ''COMMENTAIRE''                    
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('VOLUME_PHY','''ID_VOLUME_PHY'',''DESC_VOLUME_PHY'',''TOTAL_MB'',''MAJ_CD_AUTORISE'',''CHEMIN_ACCES_DEFAUT'',''STATUT'',''COMMENTAIRE''');


/*
VOLUME_PHY_CIBLE               ''ID_VOLUME_PHY''                  
VOLUME_PHY_CIBLE               ''TYPE_CIBLE''                     
VOLUME_PHY_CIBLE               ''NOM_CIBLE''                      
VOLUME_PHY_CIBLE               ''CHEMIN_ACCES''                   
*/

   SDBM_AUDIT_APPL.GENERER_TRIGGER('VOLUME_PHY_CIBLE','''TYPE_CIBLE'',''NOM_CIBLE'',''CHEMIN_ACCES''');


END;
/


DISCONNECT
EXIT
