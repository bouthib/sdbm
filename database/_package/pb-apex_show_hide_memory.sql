--
-- Credit : Inconnu
--


CREATE OR REPLACE PACKAGE BODY APEX_SHOW_HIDE_MEMORY AS


   PROCEDURE SHOW_HIDE_COLLECTION AS
 
      L_ARR             APEX_APPLICATION_GLOBAL.VC_ARR2;
      L_COLLECTION_NAME VARCHAR2(255 CHAR) := 'APEX_SHOW_HIDE_COLLECTION';
      L_FOUND           BOOLEAN := FALSE;

   BEGIN

      IF (WWV_FLOW_COLLECTION.COLLECTION_EXISTS(P_COLLECTION_NAME => L_COLLECTION_NAME) = FALSE) THEN
         HTMLDB_COLLECTION.CREATE_OR_TRUNCATE_COLLECTION(P_COLLECTION_NAME => L_COLLECTION_NAME);
      END IF;

      L_ARR := APEX_UTIL.STRING_TO_TABLE(P_STRING => V('APEX_SHOW_HIDE_TEMPORARY_ITEM'), P_SEPARATOR => ']');

      -- If the array member count of L_ARR < 3, then the following code will raise an exception
      FOR C1 IN (SELECT SEQ_ID
                   FROM APEX_COLLECTIONS
                  WHERE COLLECTION_NAME = L_COLLECTION_NAME
                    AND C001            = L_ARR(1)
                    AND C002            = L_ARR(2)
                    AND C003            = L_ARR(3)
                )

      LOOP

         -- It exists, so delete it
         APEX_COLLECTION.DELETE_MEMBER(P_COLLECTION_NAME => L_COLLECTION_NAME, P_SEQ => C1.SEQ_ID);
         L_FOUND := TRUE;

      END LOOP;

      IF L_FOUND = FALSE THEN
         APEX_COLLECTION.ADD_MEMBER(P_COLLECTION_NAME => L_COLLECTION_NAME, P_C001 => L_ARR(1), P_C002 => L_ARR(2), P_C003 => L_ARR(3));
      END IF;

     COMMIT;

   END SHOW_HIDE_COLLECTION;


   PROCEDURE SHOW_HIDE_COLLECTION_OUTPUT AS
   
   BEGIN

      HTP.PRN('<script type="text/javascript">' || CHR(10));
      HTP.PRN('<!--' || CHR(10));
      HTP.PRN('window.onload=function(){' || CHR(10));

      FOR C1 IN (SELECT C003
                   FROM APEX_COLLECTIONS
                  WHERE COLLECTION_NAME = 'APEX_SHOW_HIDE_COLLECTION'
                    AND C001            = TO_CHAR(WWV_FLOW.G_FLOW_ID)
                    AND C002            = TO_CHAR(WWV_FLOW.G_FLOW_STEP_ID)
                )
      LOOP
         HTP.PRN('htmldb_ToggleWithImage(''' || C1.C003 || 'img'',''' || C1.C003 || 'body'');' || CHR(10));
      END LOOP;

      HTP.PRN('}' || CHR(10));
      HTP.PRN('//-->' || CHR(10));
      HTP.PRN('</script>' || CHR(10));

  END SHOW_HIDE_COLLECTION_OUTPUT;


END APEX_SHOW_HIDE_MEMORY;
/
