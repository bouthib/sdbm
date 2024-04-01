//***************************************************************************
//*                                                                         *
//* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.        *
//* Licensed under the MIT license.                                         *
//* See LICENSE file in the project root for full license information.      *
//*                                                                         *
//***************************************************************************
//*                                                                         *
//* Fichier :                                                               *
//*    SDBMDaC.java                                                         *
//*                                                                         *
//* Description :                                                           *
//*    Serveur SDBM                                                         *
//*                                                                         *
//***************************************************************************


import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.DriverManager;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import java.sql.Statement;
import java.sql.Timestamp;

import java.text.SimpleDateFormat;

import java.util.Enumeration;
import java.util.Locale;
import java.util.MissingResourceException;
import java.util.Properties;
import java.util.ResourceBundle;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.util.logging.SimpleFormatter;

import java.util.regex.Pattern;

import oracle.jdbc.OracleTypes;


public class SDBMDaC implements IApp
{

   //************************************************************************
   //* Variables globales                                                   *
   //************************************************************************

   // Identification
   private static final  String           pgmname = "SDBMDaC";
   private static final  String           schname = "SDBM";
   private static final  String           version = "0.06";

   // Journalisation
   private static final  SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
   private static final  SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm:ss");
   private static        FileHandler      logFile;
   private static        SDBMLogFormatter logFormatter;

   // Paramètres d'exécution
   private static        String           pSDBMSchema;
   private               String           pSDBMConnection;
   private               String           pSDBMUserName;
   private               String           pSDBMPassword;
   private               int              pSDBMSleepTime = 999;

   private static final  int              passBeforeGarbageCollection = 50;
   private static final  int              sleepTimeOnConnectionError  = 15;
   private               Connection       repositoryConnection;
   private               Connection       targetConnection;
   private               boolean          bStart = true;

   //
   // Variables statistique
   //
   private static final  int              statTimeBetweenDisplay = 900;
   private               long             statExTimeLastDisplay  = 0;

   // Boucle
   private               long             statDtTimeOfLonguestCompletedPass = -1;
   private               long             statExTimeOfLonguestCompletedPass = -1;

   // Connexion
   private               long             statDtTimeOfLonguestTargetConnection = -1;
   private               long             statExTimeOfLonguestTargetConnection = -1;
   private               String           statTargetOfLonguestTargetConnection = "";

   // Événement
   private               long             statDtTimeOfLonguestTargetEvent = -1;
   private               long             statExTimeOfLonguestTargetEvent = -1;
   private               String           statEventNOfLonguestTargetEvent = "";
   private               String           statTargetOfLonguestTargetEvent = "";



   //************************************************************************
   //*                                                                      *
   //* Classe :                                                             *
   //*    SDBMLogFormatter                                                  *
   //*                                                                      *
   //************************************************************************
   private class SDBMLogFormatter extends SimpleFormatter
   {

      public SDBMLogFormatter()
      {
         super();
      }

      /**
       * @param logRecord
       * @return
       */
      public String format(LogRecord logRecord)
      {

         // Création d'un tampon
         StringBuffer stringBuffer = new StringBuffer();

         // Ajout de la date
         stringBuffer.append(dateFormat.format(logRecord.getMillis()));
         stringBuffer.append(" - ");

         // Ajout du niveau
         stringBuffer.append(String.format("%7s",logRecord.getLevel().getName().replaceAll("FINE","DEBUG")));
         stringBuffer.append(" : ");

         // Ajout du message formaté
         stringBuffer.append(formatMessage(logRecord));

         // Saut de ligne
         stringBuffer.append("\n");

         return stringBuffer.toString();
      }
   }



   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    writeLogMessage                                                   *
   //*                                                                      *
   //* Description :                                                        *
   //*    Envoi du message dans le journal de l'application.                *
   //*                                                                      *
   //************************************************************************
   private void writeLogMessage(Level level, String message)
   {
      LogRecord  logRecord;

      logRecord = new LogRecord(level,message);
      logRecord.setLoggerName("");

      if (logFile != null)
         logFile.publish(logRecord);
      else
         System.out.println("LEVEL: " + level.getName() + ", MESSAGE: " + message);

      // Envoi du message à la base de données (best effort)
      if (repositoryConnection != null && logFile != null && level.intValue() >= logFile.getLevel().intValue())
      {
         CallableStatement sqlStmt;

         try
         {
            sqlStmt = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.JOURNALISER(?,?,?)}");

            // Préparation des paramètres
            sqlStmt.setString("A_SOURCE",pgmname);
            sqlStmt.setString("A_NIVEAU",level.getName().replaceAll("FINE","DEBUG"));
            sqlStmt.setString("A_TEXTE",message);

            // Exécution
            sqlStmt.execute();
            sqlStmt.close();
            sqlStmt = null;
         }
         catch (SQLException ex)
         {
            logRecord.setLevel(Level.WARNING);
            logRecord.setMessage("Unable to send log message to the SDBM repository.");
            logFile.publish(logRecord);
         }
      }

   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    setLogMessageLevel                                                *
   //*                                                                      *
   //* Description :                                                        *
   //*    Ajustement du niveau de journalisation.                           *
   //*                                                                      *
   //************************************************************************
   private void setLogMessageLevel(String level)
   {
      if (!level.equalsIgnoreCase("NORMAL") && !level.equalsIgnoreCase("DEBUG"))
      {
         writeLogMessage(Level.WARNING,"Invalid value for logging level parameter (setLogMessageLevel). NORMAL logging level will be used.");
         logFile.setLevel(Level.CONFIG);
      }
      else
      {
         if (level.equalsIgnoreCase("DEBUG"))
         {
            if (logFile.getLevel() != Level.ALL)
            {
               writeLogMessage(Level.WARNING,"DEBUG logging level will be used. Performance will be impacted.");
               logFile.setLevel(Level.ALL);
            }
         }
         else
         {
            if (logFile.getLevel() != Level.CONFIG)
            {
               writeLogMessage(Level.CONFIG,"NORMAL logging level will be used.");
               logFile.setLevel(Level.CONFIG);
            }
         }
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    writeHangCheckInfo                                                *
   //*                                                                      *
   //* Description :                                                        *
   //*    Mise à jour du fichier HangCheck.                                 *
   //*                                                                      *
   //************************************************************************
   public void writeHangCheckInfo(int nbSeconds, String statut)
   {
      FileWriter hcFile;

      try
      {
         hcFile = new FileWriter("log/" + pgmname + ".HangCheckInfo");
         hcFile.write(String.valueOf(System.currentTimeMillis() / 1000 + nbSeconds) + ":" + statut);
         hcFile.close();
      }
      catch (IOException ex)
      {
         writeLogMessage(Level.SEVERE, "Unable to write to " + pgmname + ".HangCheckInfo");
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    sendStatusHangCheckInfo                                           *
   //*                                                                      *
   //* Description :                                                        *
   //*    Envoi du status relatif au fichier HangCheck.                     *
   //*                                                                      *
   //************************************************************************
   public void sendStatusHangCheckInfo()
   {
      BufferedReader brHCFile;
      String         hcData;

      try
      {
         brHCFile = new BufferedReader(new FileReader("log/" + pgmname + ".HangCheckInfo"));
         hcData = brHCFile.readLine();
         brHCFile.close();

         // Traitement du fichier vide...
         if (hcData == null)
         {
            hcData = "";
         }

         // Traitement de l'information
         if (hcData.contains(":--"))
         {
            writeLogMessage(Level.INFO, "The last shutdown was normal (hcData : " + hcData + ").");
         }
         else
         {
            writeLogMessage(Level.WARNING, "The last shutdown was not normal (hcData : " + hcData + "). The server was waiting on a target or have been restarted by the HangCheck mechanism. If this error occurs frequently, an investigation is required.");
         }
      }
      catch (IOException ex)
      {
         writeLogMessage(Level.WARNING, "Unable to read from " + pgmname + ".HangCheckInfo (the file is supposed to be automatically created).");
      }

   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    wait                                                              *
   //*                                                                      *
   //* Description :                                                        *
   //*    Chargment du fichier de paramètre.                                *
   //*                                                                      *
   //************************************************************************
   private void wait(int seconds)
   {
      try
      {
         Thread.sleep(seconds * 1000);
      }
      catch (InterruptedException ex)
      {
         writeLogMessage(Level.SEVERE,ex.getMessage().replaceAll("\n"," : NL : "));
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    setSleepTime                                                      *
   //*                                                                      *
   //* Description :                                                        *
   //*    Ajustement de la fréquence d'exécution.                           *
   //*                                                                      *
   //************************************************************************
   private void setSleepTime(int sleepTime)
   {
      if (sleepTime < 1 || sleepTime > 999)
      {
         pSDBMSleepTime = 60;
         writeLogMessage(Level.WARNING,"Invalid value for parameter sleepTime (setSleepTime). 60 seconds will be used.");
      }
      else
      {
         if (sleepTime != pSDBMSleepTime)
         {
            pSDBMSleepTime = sleepTime;
            writeLogMessage(Level.CONFIG,"The new value for parameter sleepTime is " + pSDBMSleepTime + " seconds.");
         }
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    setLoginTimeout                                                   *
   //*                                                                      *
   //* Description :                                                        *
   //*    Ajustement de la fréquence d'exécution.                           *
   //*                                                                      *
   //************************************************************************
   private void setConnectionTimeout(int loginTimeout)
   {
      if (loginTimeout != 0 && (loginTimeout < 5 || loginTimeout > 999))
      {
         DriverManager.setLoginTimeout(0);
         writeLogMessage(Level.WARNING,"Invalid value for parameter connectionTimeout (setConnectionTimeout). 0 second (default) will be used.");
      }
      else
      {
         if (loginTimeout !=  DriverManager.getLoginTimeout())
         {
            DriverManager.setLoginTimeout(loginTimeout);
            writeLogMessage(Level.CONFIG,"The new value for parameter loginTimeout is " + loginTimeout + " second(s).");
         }
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    loadParams                                                        *
   //*                                                                      *
   //* Description :                                                        *
   //*    Chargment du fichier de paramètre.                                *
   //*                                                                      *
   //************************************************************************
   private Properties loadParams(String file)
      throws IOException
   {
      Properties     prop;
      ResourceBundle bundle;
      Enumeration    enume;
      String key;

      prop = new Properties();
      bundle = ResourceBundle.getBundle(file);
      enume = bundle.getKeys();

      key = null;
      while(enume.hasMoreElements())
      {
         key = (String)enume.nextElement();
         prop.put(key, bundle.getObject(key));
      }
      return prop;
   }


    //************************************************************************
    //*                                                                      *
    //* Méthode :                                                            *
    //*    setIdentifier                                                     *
    //*                                                                      *
    //* Description :                                                        *
    //*    Mise à jour de V$SESSION.CLIENT_IDENTIFIER.                       *
    //*                                                                      *
    //************************************************************************
    private void setIdentifier(String message)
    {
       // Envoi du message à la base de données (best effort)
       if (repositoryConnection != null)
       {
          CallableStatement sqlStmt;

          try
          {
             sqlStmt = repositoryConnection.prepareCall("{call DBMS_SESSION.SET_IDENTIFIER(?)}");

             // Préparation des paramètres
             sqlStmt.setString("CLIENT_ID",message);

             // Exécution
             sqlStmt.execute();
             sqlStmt.close();
             sqlStmt = null;
          }
          catch (SQLException ex)
          {
             writeLogMessage(Level.WARNING,"Unable to send identifier (DBMS_SESSION) to SDBM repository (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
          }
       }
    }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    connectToRepository                                               *
   //*                                                                      *
   //* Description :                                                        *
   //*    Effectue une connection au référentiel SDBM.                      *
   //*                                                                      *
   //************************************************************************
   private void connectToRepository()
   {
      boolean validConnection = false;

      if (repositoryConnection != null)
      {
         try
         {
            repositoryConnection.rollback();
            validConnection = true;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Failed validation of repository connection : rollback (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            repositoryConnection = null;
         }
      }

      while (!validConnection)
      {
         try
         {
            // Connect to SDBM repository
            writeLogMessage(Level.INFO,"Trying to connect to SDBM repository (" + pSDBMConnection + ")...");
            repositoryConnection = DriverManager.getConnection("jdbc:oracle:thin:@" + pSDBMConnection,pSDBMUserName,pSDBMPassword);
            repositoryConnection.setAutoCommit(false);
            writeLogMessage(Level.INFO,"Connected to SDBM repository.");
            validConnection = true;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Unable to connect to SDBM repository (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            writeLogMessage(Level.INFO,"Waiting " + sleepTimeOnConnectionError + " seconds before trying again...");
            wait(sleepTimeOnConnectionError);
         }
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    statDisplay                                                       *
   //*                                                                      *
   //* Description :                                                        *
   //*    Affichage des statistiques et remise à zéro si la période est     *
   //*    atteinte.                                                         *
   //*                                                                      *
   //************************************************************************
   private void statDisplay()
   {
      if ((System.currentTimeMillis() - statExTimeLastDisplay) / 1000 >=  statTimeBetweenDisplay)
      {
         //
         // Affichage des valeur
         //
         writeLogMessage(Level.INFO,"Begin of dump of " + pgmname + " system statistics...");
         writeLogMessage(Level.INFO,"Java memory in use : " + (Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) + " bytes.");

         if (statExTimeOfLonguestCompletedPass != -1)
            writeLogMessage(Level.INFO,"The longuest completed pass for the period took " + statExTimeOfLonguestCompletedPass / 1000 + "." + statExTimeOfLonguestCompletedPass % 1000 + " seconds. It occurs at " + timeFormat.format(statDtTimeOfLonguestCompletedPass) + ".");

         if (statExTimeOfLonguestTargetConnection != -1)
            writeLogMessage(Level.INFO,"The longuest connection for the period took " + statExTimeOfLonguestTargetConnection + " milliseconds. It occurs at " + timeFormat.format(statDtTimeOfLonguestTargetConnection) + " while connecting to " + statTargetOfLonguestTargetConnection + ".");

         if (statExTimeOfLonguestTargetEvent != -1)
            writeLogMessage(Level.INFO,"The longuest event execution for the period took " + statExTimeOfLonguestTargetEvent + " milliseconds. It occurs at " + timeFormat.format(statDtTimeOfLonguestTargetEvent) + " while executing event " + statEventNOfLonguestTargetEvent + " on target " + statTargetOfLonguestTargetEvent + ".");

         writeLogMessage(Level.INFO,"End of dump of " + pgmname + " system statistics.");

         //
         // Remise à zéro des compteurs
         //
         statExTimeLastDisplay = System.currentTimeMillis();

         // Boucle
         statDtTimeOfLonguestCompletedPass = -1;
         statExTimeOfLonguestCompletedPass = -1;

         // Connexion
         statDtTimeOfLonguestTargetConnection = -1;
         statExTimeOfLonguestTargetConnection = -1;
         statTargetOfLonguestTargetConnection = "";

         // Événement
         statDtTimeOfLonguestTargetEvent = -1;
         statExTimeOfLonguestTargetEvent = -1;
         statEventNOfLonguestTargetEvent = "";
         statTargetOfLonguestTargetEvent = "";
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    statSaveTargetEvent                                               *
   //*                                                                      *
   //* Description :                                                        *
   //*    Sauvegarde des statistiques d'événements (si il y a lieu).        *
   //*                                                                      *
   //************************************************************************
   private void statSaveTargetEvent(String eventName, String targetName, long executionTime)
   {
      if (executionTime > statExTimeOfLonguestTargetEvent)
      {
         statDtTimeOfLonguestTargetEvent = System.currentTimeMillis();
         statExTimeOfLonguestTargetEvent = executionTime;
         statEventNOfLonguestTargetEvent = eventName;
         statTargetOfLonguestTargetEvent = targetName;
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    statSaveTargetConnection                                          *
   //*                                                                      *
   //* Description :                                                        *
   //*    Sauvegarde des statistiques de connexions (si il y a lieu).       *
   //*                                                                      *
   //************************************************************************
   private void statSaveTargetConnection(String targetName, long executionTime)
   {
      if (executionTime > statExTimeOfLonguestTargetConnection)
      {
         statDtTimeOfLonguestTargetConnection = System.currentTimeMillis();
         statExTimeOfLonguestTargetConnection = executionTime;
         statTargetOfLonguestTargetConnection = targetName;
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    statSaveCompletedPass                                             *
   //*                                                                      *
   //* Description :                                                        *
   //*    Sauvegarde des statistiques de boucle (si il y a lieu).           *
   //*                                                                      *
   //************************************************************************
   private void statSaveCompletedPass(long executionTime)
   {
      if (executionTime > statExTimeOfLonguestCompletedPass)
      {
         statDtTimeOfLonguestCompletedPass = System.currentTimeMillis();
         statExTimeOfLonguestCompletedPass = executionTime;
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    prepareCollectedData                                              *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement des données d'une collecte.                            *
   //*                                                                      *
   //************************************************************************
   private boolean prepareCollectedData()
   {
      CallableStatement sqlStmtPrepareCollectedDataExec = null;
      boolean           bReturn                         = false;

      // Mise à jour du statut d'exécution
      try
      {
         // Préparation de l'appel
         sqlStmtPrepareCollectedDataExec = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_COLLECTE.TRAITEMENT_FIN_COLLECTE_BD}");
         sqlStmtPrepareCollectedDataExec.execute();
         bReturn = true;
      }
      catch (SQLException ex1)
      {
         /* 2 tentavive pour erreur temporaire (exemple : modification du code) */
         writeLogMessage(Level.INFO,"Unable to execute SDBM_COLLECTE.TRAITEMENT_FIN_COLLECTE_BD (" + ex1.getMessage().replaceAll("\n"," : NL : ") + "). Since this call must successfully complete, it will be retry.");

         try
         {
            // Préparation de l'appel
            sqlStmtPrepareCollectedDataExec = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_COLLECTE.TRAITEMENT_FIN_COLLECTE_BD}");
            sqlStmtPrepareCollectedDataExec.execute();
            bReturn = true;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Unable to execute SDBM_COLLECTE.TRAITEMENT_FIN_COLLECTE_BD (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }

      //
      // Libération des ressources (niveau référentiel)
      //
      try
      {
         if (sqlStmtPrepareCollectedDataExec != null)
            sqlStmtPrepareCollectedDataExec.close();
         sqlStmtPrepareCollectedDataExec = null;
      }
      catch (Exception ex)
      {
         writeLogMessage(Level.WARNING,"Error while releasing repository resources for prepareCollectedData.");
      }

      return(bReturn);
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    saveCollectStatus                                                 *
   //*                                                                      *
   //* Description :                                                        *
   //*    Mise à jour du statut d'exécution d'une collecte.                 *
   //*                                                                      *
   //************************************************************************
   private boolean saveCollectStatus(String targetName, String eventName, String statut)
   {
      CallableStatement sqlStmtCollectStatusExec = null;
      boolean           bReturn                  = false;

      // Mise à jour du statut d'exécution
      try
      {
         // Préparation de l'appel
         sqlStmtCollectStatusExec = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_COLLECTE.SAUVEGARDE_STATUT_COLLECTE_BD(?,?,?)}");

         sqlStmtCollectStatusExec.setString("A_NOM_CIBLE",targetName);
         sqlStmtCollectStatusExec.setString("A_NOM_EVENEMENT",eventName);
         sqlStmtCollectStatusExec.setString("A_STATUT",statut);
         sqlStmtCollectStatusExec.execute();
         bReturn = true;
      }
      catch (SQLException ex1)
      {
         /* 2 tentavive pour erreur temporaire (exemple : modification du code) */
         writeLogMessage(Level.INFO,"Unable to save the execution status (SDBM_COLLECTE.SAUVEGARDE_STATUT_COLLECTE_BD) for event " + eventName + ", target " + targetName + " (" + ex1.getMessage().replaceAll("\n"," : NL : ") + "). Since this call must successfully complete, it will be retry.");

         try
         {
            // Préparation de l'appel
            sqlStmtCollectStatusExec = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_COLLECTE.SAUVEGARDE_STATUT_COLLECTE_BD(?,?)}");

            sqlStmtCollectStatusExec.setString("A_NOM_CIBLE",targetName);
            sqlStmtCollectStatusExec.setString("A_NOM_EVENEMENT",eventName);
            sqlStmtCollectStatusExec.setString("A_STATUT",statut);
            sqlStmtCollectStatusExec.execute();
            bReturn = true;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Unable to save the execution status (SDBM_COLLECTE.SAUVEGARDE_STATUT_COLLECTE_BD) for event " + eventName + ", target " + targetName + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }

      //
      // Libération des ressources (niveau référentiel)
      //
      try
      {
         if (sqlStmtCollectStatusExec != null)
            sqlStmtCollectStatusExec.close();
         sqlStmtCollectStatusExec = null;
      }
      catch (Exception ex)
      {
         writeLogMessage(Level.WARNING,"Error while releasing repository resources for saveCollectStatus.");
      }

      return(bReturn);
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    collectDataOfTarget                                               *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement de collecte des données     .                          *
   //*                                                                      *
   //************************************************************************
   private void collectDataOfTarget(String targetName)
   {
      CallableStatement sqlStmtEventList;
      PreparedStatement prepSqlStmt = null;

      ResultSet         sqlResultsetEventList   = null;
      ResultSet         sqlResultsetEventReturn = null;

      String[]          sqlCommands;
      boolean           bSQLExecuteOK;

      StringBuffer      sbInsertStatement = new StringBuffer();
      String            insertStatement;

      final int         batchSize = 1000;
      int               rowsCount;
      long              statStart;

      try
      {
         sqlStmtEventList   = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_COLLECTE.TRAITEMENT_COLLECTE_BD(?,?)}");

         // Enregistrement des paramètres
         sqlStmtEventList.setString("A_NOM_CIBLE",targetName);
         sqlStmtEventList.registerOutParameter("A_CUR_INFO", OracleTypes.CURSOR);

         // Exécution
         sqlStmtEventList.execute();

         // Réception de la liste des cibles à traiter
         sqlResultsetEventList = (ResultSet)sqlStmtEventList.getObject("A_CUR_INFO");

         // Traitement des collectes
         while (sqlResultsetEventList.next())
         {
            //
            // Exécution d'une collecte
            //
            try
            {
               statStart = System.currentTimeMillis();
               writeLogMessage(Level.FINE,"Event that will be processed is : " + sqlResultsetEventList.getString("NOM_EVENEMENT") + " (timeout in effect will be " + sqlResultsetEventList.getInt("DELAI_MAX_EXEC_SEC") + " seconds)...");
               setIdentifier(targetName + "." + sqlResultsetEventList.getString("NOM_EVENEMENT"));

               bSQLExecuteOK = false;
               sqlCommands = sqlResultsetEventList.getString("COMMANDE").split(Pattern.quote("{*** ALTERNATE SQL ***}"));

               for (int i = 0; i < sqlCommands.length; i++)
               {
                  if (!bSQLExecuteOK)
                  {
                     try
                     {
                        writeLogMessage(Level.FINE,"SQL command (" + i + "):\n***\n" + sqlCommands[i] + "\n***");
                        writeHangCheckInfo(sqlResultsetEventList.getInt("DELAI_MAX_EXEC_SEC"),targetName + "." + sqlResultsetEventList.getString("NOM_EVENEMENT"));

                        prepSqlStmt = targetConnection.prepareStatement(sqlCommands[i]);
                        prepSqlStmt.setQueryTimeout(sqlResultsetEventList.getInt("DELAI_MAX_EXEC_SEC"));
                        sqlResultsetEventReturn = prepSqlStmt.executeQuery();

                        bSQLExecuteOK = true;
                     }
                     catch (SQLException ex)
                     {
                        if (i == (sqlCommands.length - 1))
                        {
                           writeLogMessage(Level.WARNING,"Unable to process event " + sqlResultsetEventList.getString("NOM_EVENEMENT") + ", target " + targetName + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
                           writeLogMessage(Level.WARNING,"SQL command was :\n***\n" + sqlResultsetEventList.getString("COMMANDE") + "\n***");

                           // Calcul du nouvelle intervalle d'exécution (selon les règles du serveur
                           saveCollectStatus(targetName,sqlResultsetEventList.getString("NOM_EVENEMENT"),"ER");
                        }
                        else
                        {
                           writeLogMessage(Level.FINE,"Unable to process event " + sqlResultsetEventList.getString("NOM_EVENEMENT") + ", target " + targetName + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
                        }
                     }
                  }
               }

               if (bSQLExecuteOK)
               {
                  // Préparation de l'instruction insert
                  sbInsertStatement.setLength(0);
                  sbInsertStatement.append("INSERT INTO " + pSDBMSchema + "." + sqlResultsetEventList.getString("NOM_EVENEMENT") + " VALUES (");
                  for (int i = 1; i <= sqlResultsetEventReturn.getMetaData().getColumnCount(); i++)
                  {
                     sbInsertStatement.append("?,");
                  }

                  // Retrait de la dernière virgule et conversion en String
                  insertStatement = sbInsertStatement.toString().substring(0,sbInsertStatement.toString().length() - 1) + ")";
                  writeLogMessage(Level.FINE,"Insert statement that will be prepared is: " + insertStatement);

                  // Préparation de l'instruction
                  prepSqlStmt = repositoryConnection.prepareStatement(insertStatement);

                  writeLogMessage(Level.FINE,"Fetching data started...");

                  rowsCount = 0;
                  while (sqlResultsetEventReturn.next())
                  {
                     // Transfert des données (champs par champs)
                     for (int i = 1; i <= sqlResultsetEventReturn.getMetaData().getColumnCount(); i++)
                     {
                        // Traitement des champs DATE
                        if (sqlResultsetEventReturn.getMetaData().getColumnTypeName(i).compareToIgnoreCase("DATE") == 0)
                        {
                           prepSqlStmt.setTimestamp(i,sqlResultsetEventReturn.getTimestamp(i));
                        }
                        // Traitement du reste des types
                        else
                        {
                           prepSqlStmt.setObject(i, sqlResultsetEventReturn.getObject(i));
                        }
                     }
                     prepSqlStmt.addBatch();

                     // Prevenir une trop grande utilisation de mémoire
                     if (++rowsCount % batchSize == 0)
                     {
                        prepSqlStmt.executeBatch();
                     }
                  }
                  // Fin while
                  prepSqlStmt.executeBatch();
                  writeLogMessage(Level.FINE,"Fetching data ended: " + prepSqlStmt.getUpdateCount() + " record(s) has been processed");

                  // Calcul du nouvelle intervalle d'exécution
                  saveCollectStatus(targetName,sqlResultsetEventList.getString("NOM_EVENEMENT"),"OK");

                  // Mise à jour des statistiques
                  statSaveTargetEvent(sqlResultsetEventList.getString("NOM_EVENEMENT"), targetName, (System.currentTimeMillis() - statStart));
               }
            }
            catch (SQLException ex)
            {
               // Échec de l'exécution de l'événement
               if (ex.getErrorCode() == 1)
               {
                  // Calcul du nouvelle intervalle d'exécution
                  saveCollectStatus(targetName,sqlResultsetEventList.getString("NOM_EVENEMENT"),"UK");

                  writeLogMessage(Level.INFO,"Unable to process event " + sqlResultsetEventList.getString("NOM_EVENEMENT") + ", target " + targetName + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
               }
               else
               {
                  writeLogMessage(Level.WARNING,"Unable to process event " + sqlResultsetEventList.getString("NOM_EVENEMENT") + ", target " + targetName + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
                  writeLogMessage(Level.WARNING,"SQL command was :\n***\n" + sqlResultsetEventList.getString("COMMANDE") + "\n***");

                  // Calcul du nouvelle intervalle d'exécution (selon les règles du serveur
                  saveCollectStatus(targetName,sqlResultsetEventList.getString("NOM_EVENEMENT"),"ER");
               }
            }

            //
            // Libération des ressources (cible)
            //
            try
            {
               // Si erreur
               if (sqlResultsetEventReturn != null)
                  sqlResultsetEventReturn.close();
               sqlResultsetEventReturn = null;

               // Si erreur
               if (prepSqlStmt != null)
                   prepSqlStmt.close();
               prepSqlStmt = null;
            }
            catch (SQLException ex)
            {
               writeLogMessage(Level.WARNING,"Error while releasing resources from target database " + sqlResultsetEventList.getString("NOM_CIBLE") + " - monitorEvents (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            }

         }
         // Fin de l'instruction while

         //
         // Libération des ressources (référentiel)
         //
         try
         {
            sqlResultsetEventList.close();
            sqlResultsetEventList = null;

            sqlStmtEventList.close();
            sqlStmtEventList = null;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for monitorEvents.");
         }
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to get the event list (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    collectData                                                       *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement de collecte pricipal.                                  *
   //*                                                                      *
   //************************************************************************
   private void collectData()
   {
      //
      //
      // Connect to SDBM repository
      //
      //
      connectToRepository();

      // Envoi de l'information sur le dernier arrêt (si nous sommes en mode démarrage)
      if (bStart)
      {
         sendStatusHangCheckInfo();
         bStart = false;
      }

      //
      //
      // Traitement des cibles
      //
      //
      CallableStatement sqlStmtTargetList;
      PreparedStatement prepSqlStmt = null;

      ResultSet         sqlResultsetTargetList     = null;
      ResultSet         sqlResultsetDatabaseStatus = null;

      Properties        infoOracle;

      boolean           bDataCollected    = false;
      long              statStart         = 0;
      String            sqlDatabaseStatus = null;

      try
      {
         // Préparation des appels (obtenir la liste / enregistrement des statuts)
         sqlStmtTargetList = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_COLLECTE.TRAITEMENT_CIBLES_BD(?,?,?,?)}");

         // Enregistrement des paramètres
         sqlStmtTargetList.setString("A_VERSION_SERVEUR",version);
         sqlStmtTargetList.registerOutParameter("A_CUR_INFO", OracleTypes.CURSOR);
         sqlStmtTargetList.registerOutParameter("A_DELAI_MAX_CONNEXION_SEC", OracleTypes.INTEGER);
         sqlStmtTargetList.registerOutParameter("A_NIVEAU_JOURNAL_SERVEUR", OracleTypes.VARCHAR);

         // Exécution
         sqlStmtTargetList.execute();

         // Réception de la liste des cibles à traiter
         sqlResultsetTargetList = (ResultSet)sqlStmtTargetList.getObject("A_CUR_INFO");

         // Réception du délai max. de connexion
         setConnectionTimeout(sqlStmtTargetList.getInt("A_DELAI_MAX_CONNEXION_SEC"));

         // Réception du délai de vérification
         setSleepTime(10);

         // Réception du niveau de journalisation
         setLogMessageLevel(sqlStmtTargetList.getString("A_NIVEAU_JOURNAL_SERVEUR"));

         // Traitement des cibles
         infoOracle = new Properties();
         while (sqlResultsetTargetList.next())
         {
            //
            // Connexion à la base de données cible
            //
            try
            {
               statStart = System.currentTimeMillis();
               writeLogMessage(Level.FINE,"Trying to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + "...");
               setIdentifier(sqlResultsetTargetList.getString("NOM_CIBLE"));
               writeHangCheckInfo(sqlStmtTargetList.getInt("A_DELAI_MAX_CONNEXION_SEC"),sqlResultsetTargetList.getString("NOM_CIBLE"));

               if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("OR"))
               {
                  infoOracle.clear();
                  infoOracle.put("user", sqlResultsetTargetList.getString("NOM_USAGER"));
                  infoOracle.put("password", sqlResultsetTargetList.getString("MOT_PASSE"));

                  // Si la connexion doit être (SYSOPER ou SYSDBA)
                  if (sqlResultsetTargetList.getString("TYPE_CONNEXION").contentEquals("SD"))
                  {
                     infoOracle.put("internal_logon","sysdba");
                  }

                  try
                  {
                     targetConnection = DriverManager.getConnection("jdbc:oracle:thin:@" + sqlResultsetTargetList.getString("CONNEXION"),infoOracle);
                  }
                  catch (SQLException exTargetConnection)
                  {
                     if (exTargetConnection.getMessage().contentEquals("Io exception: Got minus one from a read call"))
                     {
                        // Deuxième essai si l'erreur est : Io exception: Got minus one from a read call
                        writeLogMessage(Level.INFO,"Unable to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + exTargetConnection.getMessage().replaceAll("\n"," : NL : ") + "). Will try again...");
                        targetConnection = DriverManager.getConnection("jdbc:oracle:thin:@" + sqlResultsetTargetList.getString("CONNEXION"),infoOracle);
                     }
                     else
                     {
                        throw exTargetConnection;
                     }

                  }
               }

               else if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("MS"))
               {
                  try
                  {
                     targetConnection = DriverManager.getConnection("jdbc:sqlserver:" + sqlResultsetTargetList.getString("CONNEXION"),sqlResultsetTargetList.getString("NOM_USAGER"),sqlResultsetTargetList.getString("MOT_PASSE"));
                     targetConnection.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
                  }
                  catch (SQLException exTargetConnection)
                  {
                     if (exTargetConnection.getMessage().contentEquals("Io exception: Got minus one from a read call"))
                     {
                        // Deuxième essai si l'erreur est : Io exception: Got minus one from a read call
                        writeLogMessage(Level.INFO,"Unable to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + exTargetConnection.getMessage().replaceAll("\n"," : NL : ") + "). Will try again...");
                        targetConnection = DriverManager.getConnection("jdbc:sqlserver:" + sqlResultsetTargetList.getString("CONNEXION"),sqlResultsetTargetList.getString("NOM_USAGER"),sqlResultsetTargetList.getString("MOT_PASSE"));
                        targetConnection.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
                     }
                     else
                     {
                        throw exTargetConnection;
                     }

                  }
               }

               else if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("MY"))
               {
                  try
                  {
                     targetConnection = DriverManager.getConnection("jdbc:mysql:" + sqlResultsetTargetList.getString("CONNEXION") + "/INFORMATION_SCHEMA",sqlResultsetTargetList.getString("NOM_USAGER"),sqlResultsetTargetList.getString("MOT_PASSE"));
                     targetConnection.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
                  }
                  catch (SQLException exTargetConnection)
                  {
                     if (exTargetConnection.getMessage().contentEquals("Io exception: Got minus one from a read call"))
                     {
                        // Deuxième essai si l'erreur est : Io exception: Got minus one from a read call
                        writeLogMessage(Level.INFO,"Unable to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + exTargetConnection.getMessage().replaceAll("\n"," : NL : ") + "). Will try again...");
                        targetConnection = DriverManager.getConnection("jdbc:mysql:" + sqlResultsetTargetList.getString("CONNEXION") + "/INFORMATION_SCHEMA",sqlResultsetTargetList.getString("NOM_USAGER"),sqlResultsetTargetList.getString("MOT_PASSE"));
                        targetConnection.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
                     }
                     else
                     {
                        throw exTargetConnection;
                     }

                  }
               }

               else
               {
                  writeLogMessage(Level.WARNING,"Database type : " + sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE") + " for target database " + sqlResultsetTargetList.getString("NOM_CIBLE") + " is not supported.");
               }

               writeLogMessage(Level.FINE,"Connected to " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");

               // Statistique
               statSaveTargetConnection(sqlResultsetTargetList.getString("NOM_CIBLE"), (System.currentTimeMillis() - statStart));

               // Traitement des collectes sur la cible
               collectDataOfTarget(sqlResultsetTargetList.getString("NOM_CIBLE"));
               bDataCollected = true;
            }
            catch (SQLException exTargetConnection)
            {
               // Échec de connexion à la base de données cible
               writeLogMessage(Level.INFO,"Unable to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + exTargetConnection.getMessage().replaceAll("\n"," : NL : ") + ").");
            }

            //
            // Libération des ressources cibles
            //
            try
            {
               // En cas d'erreur
               if (sqlResultsetDatabaseStatus != null)
                  sqlResultsetDatabaseStatus.close();
               sqlResultsetDatabaseStatus = null;

               // En cas d'erreur
               if (prepSqlStmt != null)
                  prepSqlStmt.close();
               prepSqlStmt = null;

               // Fermeture de la connexion cible
               if (targetConnection != null && !targetConnection.isClosed())
               {
                  targetConnection.close();
                  writeLogMessage(Level.FINE,"Disconnected from " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");
               }

               targetConnection = null;
            }
            catch (SQLException ex)
            {
               writeLogMessage(Level.WARNING,"Error while releasing resources from target database " + sqlResultsetTargetList.getString("NOM_CIBLE") + " - collectData (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            }

            // Fin de la transaction
            try
            {
               repositoryConnection.commit();
            }
            catch (SQLException ex)
            {
               writeLogMessage(Level.SEVERE,"Error on commit within SDBM repository for target " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            }

         }
         // Fin de l'instruction while
         setIdentifier("--");
         writeHangCheckInfo(0,"--");

         // Si des données ont été reçues...
         if (bDataCollected)
         {
            writeLogMessage(Level.FINE,"prepareCollectedData (SDBM_COLLECTE.TRAITEMENT_FIN_COLLECTE_BD) started...");
            prepareCollectedData();
            writeLogMessage(Level.FINE,"prepareCollectedData (SDBM_COLLECTE.TRAITEMENT_FIN_COLLECTE_BD) ended.");
         }


         //
         // Libération des ressources (niveau référentiel)
         //
         try
         {
            // Générale
            infoOracle.clear();
            infoOracle = null;

            sqlResultsetTargetList.close();
            sqlResultsetTargetList = null;

            sqlStmtTargetList.close();
            sqlStmtTargetList = null;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for collectData.");
         }
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to get the target list (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    start                                                             *
   //*                                                                      *
   //* Description :                                                        *
   //*    Execution du programme principal.                                 *
   //*                                                                      *
   //************************************************************************
   public void start()
   {
      // Préparation du système de journalisation
      try
      {
         logFile = new FileHandler("log/" + pgmname + ".%g.log",10485760,5);
      }
      catch (IOException e)
      {
         writeLogMessage(Level.SEVERE, "Unable to open logfile (./log/" + pgmname + ".n.log)");
         System.exit(1);
      }
      logFormatter = new SDBMLogFormatter();
      logFile.setFormatter(logFormatter);
      logFile.setLevel(Level.FINEST);  // Temporaire (jusqu'à la connexion au référentiel)

      try
      {
         writeLogMessage(Level.INFO,pgmname + " version " + version + " (schema " + pSDBMSchema + ")");

         //
         // Chargement du fichier de paramètre
         //
         writeLogMessage(Level.INFO,"Reading properties files...");
         Properties prop = loadParams(pgmname);
         writeLogMessage(Level.INFO,"Reading properties files completed.");

         //
         // Sauvegarde des paramètres
         //
         pSDBMConnection = prop.getProperty("SDBMConnection");
         if (pSDBMConnection == null)
         {
            pSDBMConnection = "";
         }

         pSDBMUserName = prop.getProperty("SDBMUserName");
         if (pSDBMUserName == null)
         {
            pSDBMUserName = "";
            pSDBMPassword = "";
         }
         else
         {
            // Si le nom d'usager n'est pas vide
            pSDBMPassword = prop.getProperty("SDBMPassword");
            if (pSDBMPassword == null)
            {
               pSDBMPassword = "";
            }
         }

         //
         // Affichage des paramètres
         //
         writeLogMessage(Level.INFO,"The following initialisation parameters will be used :");

         // SDBMConnection
         writeLogMessage(Level.INFO,"SDBMConnection : " + pSDBMConnection);

         // SDBMUserName et pSDBMPassword
         writeLogMessage(Level.INFO,"SDBMUserName   : " + pSDBMUserName);
         writeLogMessage(Level.INFO,"SDBMPassword   : * String of " + pSDBMPassword.length() + " car. *");

         //
         // Validation des paramètres
         //
         writeLogMessage(Level.INFO,"Checking initialisation parameters...");

         if (pSDBMConnection.contentEquals(""))
         {
            writeLogMessage(Level.SEVERE,"SDBMConnection is a mandatory parameters.");
            System.exit(1);
         }
         if (pSDBMUserName.contentEquals(""))
         {
            writeLogMessage(Level.SEVERE,"SDBMUserName is a mandatory parameters.");
            System.exit(1);
         }
         if (pSDBMPassword.contentEquals(""))
         {
            writeLogMessage(Level.SEVERE,"SDBMPassword is a mandatory parameters.");
            System.exit(1);
         }

         writeLogMessage(Level.INFO,"Checking initialisation parameters completed.");


         // Traitement principal
         writeLogMessage(Level.INFO,"Registering JDBC drivers...");
         DriverManager.registerDriver(new oracle.jdbc.driver.OracleDriver());
         writeLogMessage(Level.INFO,"oracle.jdbc.driver.OracleDriver() has been registered.");
         DriverManager.registerDriver(new com.microsoft.sqlserver.jdbc.SQLServerDriver());
         writeLogMessage(Level.INFO,"com.microsoft.sqlserver.jdbc.SQLServerDriver() has been registered.");
         DriverManager.registerDriver(new com.mysql.cj.jdbc.Driver());
         writeLogMessage(Level.INFO,"com.mysql.cj.jdbc.Driver() has been registered.");
         writeLogMessage(Level.INFO,"Registering JDBC drivers completed.");

         int  intGarbageCollection = 0;
         long statStart;
         while (true)
         {
            // Mise à jour du compteur avant GC
            if (intGarbageCollection != 0)
            {
               intGarbageCollection--;
            }
            else
            {
               writeLogMessage(Level.FINE,"Garbage collection is force to run every " + passBeforeGarbageCollection + " completed pass.  Invoking System.gc()...");
               writeLogMessage(Level.FINE,"Java memory in use - before garbage collection : " + (Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) + " bytes.");
               System.gc();
               writeLogMessage(Level.FINE,"Java memory in use - after garbage collection  : " + (Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) + " bytes.");
               intGarbageCollection = passBeforeGarbageCollection;
            }

            statDisplay();
            statStart = System.currentTimeMillis();
            collectData();
            statSaveCompletedPass((System.currentTimeMillis() - statStart));
            Thread.sleep(pSDBMSleepTime * 1000);
         }

      }

      catch(MissingResourceException ex)
      {
         // Erreur du lecture du fichier de configuration
         writeLogMessage(Level.SEVERE,"Unable to read " + pgmname + ".properties file.");
         System.exit(1);
      }
      catch(Exception ex)
      {
         // Erreur générale
         writeLogMessage(Level.SEVERE,ex.getMessage().replaceAll("\n"," : NL : "));
      }

   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    shutdown                                                          *
   //*                                                                      *
   //* Description :                                                        *
   //*    Arrêt du programme principal.                                     *
   //*                                                                      *
   //************************************************************************
   public void shutdown()
   {
      writeLogMessage(Level.INFO, "Shutdown initiated...");

      // Fermeture de la connexion à une cible (s'il y a lieu)
      if (targetConnection != null)
      {
         try
         {
            writeLogMessage(Level.INFO,"Closing target connection...");
            targetConnection.close();
            writeLogMessage(Level.INFO,"Closing target connection completed.");
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while closing target connection (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            targetConnection = null;
         }
      }

      // Fermeture de la connexion au référentiel (s'il y a lieu)
      if (repositoryConnection != null)
      {
         try
         {
            writeLogMessage(Level.INFO,"Closing repository connection...");
            repositoryConnection.rollback();
            repositoryConnection.close();
            repositoryConnection = null;
            writeLogMessage(Level.INFO,"Closing repository connection completed.");
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while closing repository connection (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            repositoryConnection = null;
         }
      }
      writeLogMessage(Level.INFO, "Shutdown completed.");

      if (logFile != null)
         logFile.close();
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    main                                                              *
   //*                                                                      *
   //* Description :                                                        *
   //*    Démarrage du programme principal.                                 *
   //*                                                                      *
   //************************************************************************

   /**
    * @param args
    */
   public static void main(String args[])
   {
      // Ajustement de la langue
      Locale.setDefault(Locale.ENGLISH);

      // Réception du paramètre s'il y a lieu
      try
      {
         pSDBMSchema = args[0];
      }
      catch (ArrayIndexOutOfBoundsException ex)
      {
         pSDBMSchema = schname;
      }

      IApp app = new SDBMDaC();
      ShutdownInterceptor shutdownInterceptor = new ShutdownInterceptor(app);
      Runtime.getRuntime().addShutdownHook(shutdownInterceptor);
      app.start();
   }

}
