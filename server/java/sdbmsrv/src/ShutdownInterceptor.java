//***************************************************************************
//*                                                                         *
//* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.        *
//* Licensed under the MIT license.                                         *
//* See LICENSE file in the project root for full license information.      *
//*                                                                         *
//***************************************************************************


public class ShutdownInterceptor extends Thread
{
   private IApp app;

   /**
    * @param app
    */
   public ShutdownInterceptor(IApp app)
   {
      this.app = app;
   }

   public void run()
   {
      app.shutdown();
   }
}
