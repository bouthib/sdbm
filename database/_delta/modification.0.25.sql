-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 2 5  -   B e t a   --
---------------------------------------------
---------------------------------------------


#
# Mise à jour CentOS / Mise à jour à APEX 4.0
#    (voir CentOS 5.5.update.txt)
#



#
# Correctif suite à APEX 4.0 (mise à jour) - avec oracle
#

sqlplus SDBM/admin
@../_package/pb-sdbm_agent.sql
@../_package/pb-apex_show_hide_memory.sql

UPDATE SDBM.EVENEMENT
   SET COMMANDE = '
SELECT GL1.SID || '' ('' || INS.INSTANCE_NAME || '')''
      ,''La session '' || GL1.SID || '' (SID), '' || INS.INSTANCE_NAME || '' (INSTANCE), ''
       || (SELECT NVL(USERNAME,''NULL'')
             FROM GV$SESSION
            WHERE INST_ID = GL1.INST_ID
              AND SID     = GL1.SID
          )
       || '' (USERNAME) est en attente d''''un lock sur l''''objet ''
       || NVL((SELECT OWNER || ''.'' || OBJECT_NAME
                 FROM DBA_OBJECTS      OBJ
                     ,GV$LOCKED_OBJECT LKO
                WHERE OBJ.OBJECT_ID  = LKO.OBJECT_ID
                  AND LKO.INST_ID    = GL1.INST_ID
                  AND LKO.SESSION_ID = GL1.SID
                  AND ROWNUM        <= 1
              )
             ,GL1.ID1
             )
       || '' (mode requis : '' || DECODE(GL1.REQUEST
                                      ,0,''None''
                                      ,1,''Null''
                                      ,2,''Row share''
                                      ,3,''Row exclusive''
                                      ,4,''Share''
                                      ,5,''Share + Row exclusive''
                                      ,6,''Exclusive''
                                      ,GL1.REQUEST
                                      )
       || '') depuis '' || GL1.CTIME || '' secondes.''
       || NVL((SELECT '' La session '' || ML1.SID || '' (SID), ''
                                     || MIN.INSTANCE_NAME || '' (INSTANCE) détient la ressource requise (mode : '' || DECODE(ML1.LMODE
                                                                                                                          ,0,''None''
                                                                                                                          ,1,''Null''
                                                                                                                          ,2,''Row share''
                                                                                                                          ,3,''Row exclusive''
                                                                                                                          ,4,''Share''
                                                                                                                          ,5,''Share + Row exclusive''
                                                                                                                          ,6,''Exclusive''
                                                                                                                          ,ML1.LMODE
                                                                                                                          )
                      || '') depuis plus de '' || ML1.CTIME || '' secondes.''
                 FROM GV$LOCK     ML1
                     ,GV$INSTANCE MIN
                WHERE ML1.INST_ID = MIN.INST_ID
                  AND ML1.ID1     = GL1.ID1
                  AND ML1.BLOCK  != 0
                  AND ROWNUM     <= 1
              )
             ,'' Impossible d''''obtenir l''''information sur la session qui détient la ressource.''
             )
  FROM GV$LOCK     GL1
      ,GV$INSTANCE INS
 WHERE GL1.INST_ID  = INS.INST_ID
   AND GL1.BLOCK    = 0
   AND GL1.REQUEST != 0
   AND GL1.CTIME    > 300 /* 5 minutes */
'
WHERE TYPE_CIBLE      = 'BD'
  AND SOUS_TYPE_CIBLE = 'OR'
  AND NOM_EVENEMENT   = 'BLOCKING_LOCKS';


DELETE FROM SDBM.EVENEMENT_DEFAUT_TRADUCTION
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'OR'
   AND NOM_EVENEMENT   = 'BLOCKING_LOCKS';

INSERT INTO SDBM.EVENEMENT_DEFAUT_TRADUCTION
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,CHAINE_FR
  ,CHAINE_AN
  ,COMMENTAIRE_FR
  ,COMMENTAIRE_AN
)
VALUES
(
   'BD'
  ,'OR'
  ,'BLOCKING_LOCKS'
  ,(SELECT SUBSTR(COMMANDE,1,INSTR(COMMANDE,'information sur la session qui détient la ressource.''') + 53)
      FROM SDBM.EVENEMENT
     WHERE TYPE_CIBLE = 'BD'
       AND SOUS_TYPE_CIBLE = 'OR'
       AND NOM_EVENEMENT   = 'BLOCKING_LOCKS'
   )
  ,'
SELECT GL1.SID || '' ('' || INS.INSTANCE_NAME || '')''
      ,''The session '' || GL1.SID || '' (SID), '' || INS.INSTANCE_NAME || '' (INSTANCE), ''
       || (SELECT NVL(USERNAME,''NULL'')
             FROM GV$SESSION
            WHERE INST_ID = GL1.INST_ID
              AND SID     = GL1.SID
          )
       || '' (USERNAME) is waiting for the object ''
       || NVL((SELECT OWNER || ''.'' || OBJECT_NAME
                 FROM DBA_OBJECTS      OBJ
                     ,GV$LOCKED_OBJECT LKO
                WHERE OBJ.OBJECT_ID  = LKO.OBJECT_ID
                  AND LKO.INST_ID    = GL1.INST_ID
                  AND LKO.SESSION_ID = GL1.SID
                  AND ROWNUM        <= 1
              )
             ,GL1.ID1
             )
       || '' (mode required : '' || DECODE(GL1.REQUEST
                                      ,0,''None''
                                      ,1,''Null''
                                      ,2,''Row share''
                                      ,3,''Row exclusive''
                                      ,4,''Share''
                                      ,5,''Share + Row exclusive''
                                      ,6,''Exclusive''
                                      ,GL1.REQUEST
                                      )
       || '') since '' || GL1.CTIME || '' seconds.''
       || NVL((SELECT '' The session '' || ML1.SID || '' (SID), ''
                                      || MIN.INSTANCE_NAME || '' (INSTANCE) has the requested resource (mode : '' || DECODE(ML1.LMODE
                                                                                                                         ,0,''None''
                                                                                                                         ,1,''Null''
                                                                                                                         ,2,''Row share''
                                                                                                                         ,3,''Row exclusive''
                                                                                                                         ,4,''Share''
                                                                                                                         ,5,''Share + Row exclusive''
                                                                                                                         ,6,''Exclusive''
                                                                                                                         ,ML1.LMODE
                                                                                                                         )
                      || '') since more than '' || ML1.CTIME || '' seconds.''
                 FROM GV$LOCK     ML1
                     ,GV$INSTANCE MIN
                WHERE ML1.INST_ID = MIN.INST_ID
                  AND ML1.ID1     = GL1.ID1
                  AND ML1.BLOCK  != 0
                  AND ROWNUM     <= 1
              )
             ,'' Unable to get the information on the owner of the required resource.'''
  ,'Vérification des vérouillages'
  ,'Validate that no blocking lock exists'
);

exit
