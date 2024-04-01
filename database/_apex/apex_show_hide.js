//
// Credit : Inconnu
//


function SaveOnDemand(pThis)
{
   var get = new htmldb_Get(null,html_GetElement('pFlowId').value,'APPLICATION_PROCESS=APEX_SHOW_HIDE_COLLECTION',0);
   get.add('APEX_SHOW_HIDE_TEMPORARY_ITEM',html_GetElement('pFlowId').value+']'+html_GetElement('pFlowStepId').value+']'+pThis);
   gReturn = get.get();
   get = null;
   return
}

var g_ToggleBaseImageHidden = 'plus'
var g_ToggleBaseImageShown  = 'minus'

function htmldb_ToggleTableBody(pThis,pNd)
{
    pThis = $x(pThis);
    if(html_CheckImageSrc(pThis,g_ToggleBaseImageHidden))
    {
       pThis.className = gToggleWithImageI;
       pThis.src = html_replace(pThis.src,g_ToggleBaseImageHidden,g_ToggleBaseImageShown);
    }
    else
    {
       pThis.className = gToggleWithImageA;
       pThis.src = html_replace(pThis.src,g_ToggleBaseImageShown,g_ToggleBaseImageHidden);
    }
    var node = $x_Toggle(pNd);
    return;
}

function $r_ToggleAndSave(pThis,pId)
{
   htmldb_ToggleWithImage(pThis,pId+'body');
   SaveOnDemand(pId);
   return
}
