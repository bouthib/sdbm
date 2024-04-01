set define off
set verify off
set serveroutput on size 1000000
set feedback off
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
begin wwv_flow.g_import_in_progress := true; end; 
/
 
--       AAAA       PPPPP   EEEEEE  XX      XX
--      AA  AA      PP  PP  EE       XX    XX
--     AA    AA     PP  PP  EE        XX  XX
--    AAAAAAAAAA    PPPPP   EEEE       XXXX
--   AA        AA   PP      EE        XX  XX
--  AA          AA  PP      EE       XX    XX
--  AA          AA  PP      EEEEEE  XX      XX
prompt  Set Credentials...
 
begin
 
  -- Assumes you are running the script connected to SQL*Plus as the Oracle user APEX_030200 or as the owner (parsing schema) of the application.
  wwv_flow_api.set_security_group_id(p_security_group_id=>1934305315547664);
 
end;
/

begin wwv_flow.g_import_in_progress := true; end;
/
begin 

select value into wwv_flow_api.g_nls_numeric_chars from nls_session_parameters where parameter='NLS_NUMERIC_CHARACTERS';

end;

/
begin execute immediate 'alter session set nls_numeric_characters=''.,''';

end;

/
begin wwv_flow.g_browser_language := 'fr-ca'; end;
/
prompt  Check Compatibility...
 
begin
 
-- This date identifies the minimum version required to import this file.
wwv_flow_api.set_version(p_version_yyyy_mm_dd=>'2009.01.12');
 
end;
/

prompt  Set Application ID...
 
begin
 
   -- SET APPLICATION ID
   wwv_flow.g_flow_id := 0;
   wwv_flow_api.g_id_offset := 0;
null;
 
end;
/

--applications/shared_components/files/other_files
prompt  ...static file repository
set linesize 250
--
 
begin
 
    wwv_flow_html_api.remove_html(p_html_name => 'apex_show_hide.js');
   null;
 
end;
/

begin
    wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
    wwv_flow_image_api.g_varchar2_table(1) := '66756E6374696F6E20536176654F6E44656D616E64287054686973290D0A7B0D0A20202076617220676574203D206E65772068746D6C64625F476574286E756C6C2C68746D6C5F476574456C656D656E74282770466C6F77496427292E76616C75652C27';
    wwv_flow_image_api.g_varchar2_table(2) := '4150504C49434154494F4E5F50524F434553533D415045585F53484F575F484944455F434F4C4C454354494F4E272C30293B0D0A2020206765742E6164642827415045585F53484F575F484944455F54454D504F524152595F4954454D272C68746D6C5F';
    wwv_flow_image_api.g_varchar2_table(3) := '476574456C656D656E74282770466C6F77496427292E76616C75652B275D272B68746D6C5F476574456C656D656E74282770466C6F7753746570496427292E76616C75652B275D272B7054686973293B0D0A2020206752657475726E203D206765742E67';
    wwv_flow_image_api.g_varchar2_table(4) := '657428293B0D0A202020676574203D206E756C6C3B0D0A20202072657475726E0D0A7D0D0A0D0A76617220675F546F67676C6542617365496D61676548696464656E203D2027706C7573270D0A76617220675F546F67676C6542617365496D6167655368';
    wwv_flow_image_api.g_varchar2_table(5) := '6F776E20203D20276D696E7573270D0A0D0A66756E6374696F6E2068746D6C64625F546F67676C655461626C65426F64792870546869732C704E64290D0A7B0D0A202020207054686973203D202478287054686973293B0D0A2020202069662868746D6C';
    wwv_flow_image_api.g_varchar2_table(6) := '5F436865636B496D6167655372632870546869732C675F546F67676C6542617365496D61676548696464656E29290D0A202020207B0D0A2020202020202070546869732E636C6173734E616D65203D2067546F67676C6557697468496D616765493B0D0A';
    wwv_flow_image_api.g_varchar2_table(7) := '2020202020202070546869732E737263203D2068746D6C5F7265706C6163652870546869732E7372632C675F546F67676C6542617365496D61676548696464656E2C675F546F67676C6542617365496D61676553686F776E293B0D0A202020207D0D0A20';
    wwv_flow_image_api.g_varchar2_table(8) := '202020656C73650D0A202020207B0D0A2020202020202070546869732E636C6173734E616D65203D2067546F67676C6557697468496D616765413B0D0A2020202020202070546869732E737263203D2068746D6C5F7265706C6163652870546869732E73';
    wwv_flow_image_api.g_varchar2_table(9) := '72632C675F546F67676C6542617365496D61676553686F776E2C675F546F67676C6542617365496D61676548696464656E293B0D0A202020207D0D0A20202020766172206E6F6465203D2024785F546F67676C6528704E64293B0D0A2020202072657475';
    wwv_flow_image_api.g_varchar2_table(10) := '726E3B0D0A7D0D0A0D0A66756E6374696F6E2024725F546F67676C65416E64536176652870546869732C704964290D0A7B0D0A20202068746D6C64625F546F67676C6557697468496D6167652870546869732C7049642B27626F647927293B0D0A202020';
    wwv_flow_image_api.g_varchar2_table(11) := '536176654F6E44656D616E6428704964293B0D0A20202072657475726E0D0A7D';
 
end;
/

 
declare
  l_name    varchar2(255);
  l_html_id number := null;
begin
  l_name := 'apex_show_hide.js';
  l_html_id := wwv_flow_html_api.new_html_repository_record(
    p_name=> l_name,
    p_varchar2_table=> wwv_flow_image_api.g_varchar2_table,
    p_mimetype=> 'application/octet-stream',
    p_flow_id=> 0,
    p_notes=> '');
 
end;
/

commit;
begin 
execute immediate 'alter session set nls_numeric_characters='''||wwv_flow_api.g_nls_numeric_chars||'''';
end;
/
set verify on
set feedback on
prompt  ...done
