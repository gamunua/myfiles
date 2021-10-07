
                           
  UPDATE GEN_ERROR_CODE SET ERROR_DESCRIPTION ='Address 1 is Invalid.' ERROR_CODE  ='REG10075';

 



   INSERT INTO gen_error_code (module_code, 
   error_code, 
   error_warning_ind, 
   error_description, 
   created_by, 
   created_date, 
   last_modified_by, 
   last_modified_date, 
   subscriber_code)
    select module_code, 
   'SME_RCM_BFL', 
   error_warning_ind, 
   'Retro claim cant be submitted prior to Flown.', 
   created_by, 
   created_date, 
   last_modified_by, 
   last_modified_date, 
   subscriber_code from  gen_error_code  WHERE ERROR_CODE ='SME_CONTRT01' ;
                           
                          
