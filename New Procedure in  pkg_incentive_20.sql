
--New Procedure in pkg_incentive_20 for BB Incentive Search
 

 Procedure Incentive_BB_search_pr(Pi_product_code in inc_hdr.sales_product_code%type, --Mandatory
                              Pi_customer_type in varchar2,                       --Mandatory
                              Pi_created_from in Date,                            --Mandatory
                              Pi_created_to in Date,                              --Mandatory
                              Pi_application_code in VARCHAR2,                    --Mandatory
                              Pi_user_name in varchar2,                           --Mandatory
                              Pi_customer_name in varchar2,                       --Optional
                              Pi_status in varchar2,                              --Mandatory???...Better Make it Mandatory?>multiple comma seperated statuses
                              Pi_Source in varchar2,                              --Optional
                              Pi_deal_code in varchar2,                           --Optional
                              Pi_promo_code in varchar2,                          --Optional
                              Pi_contract_number in varchar2,                     --Optional
                              Pi_location_type in varchar2 ,                       --Optional -- added for location type
                              Pi_country in varchar2,                             --Optional - name is only country it can be region,network,country 
                              Pi_pending_with in varchar2,                        --Optional
                              Pi_cons_status  in varchar2,                        --Optional
                              Pi_inc_from     in Date,                            --Optional
                              Pi_inc_to       in Date,                            --Optional
                              Pi_inc_city  in varchar2,                           --Optional
                              Pi_soto_ind  in varchar2,                           --Optional
                              Pi_group_status in varchar2,                        --Optional
                              Pi_payout_frequency in varchar2,                    --Optional(Done on 01-AUG-2016)
                              Pi_is_product_level in varchar2, 
                              Pi_currency_code    in varchar2,                              
                              Pi_page_number in NUMBER,                           --Mandatory
                              Pi_page_size in NUMBER,                             --Mandatory
                              pi_soto_inc_cntry in varchar2,
                              pi_soto_loc_search in varchar2 default 'Y', 
                              Pi_pending_with_me  in VARCHAR2 default NULL,
                              Pi_requested_by_me   in varchar2 default NULL,
                              Pi_approved_by_me    in varchar2 default NULL,
                              Pi_incentive_id in number default NULL,
                              Pi_incentive_name IN VARCHAR2 default NULL,
                              pi_agreement_status IN VARCHAR2 default NULL, --added for US 
                              Po_output   OUT SYS_REFCURSOR,
                              Po_output_product out SYS_REFCURSOR
                              )  IS

v_customer_name  customer_profile.customer_name%type := NULL;
V_COUNTRY_DTL TY_COUNTRY_DTL := TY_COUNTRY_DTL();

v_max_date varchar2(20) :=null ;

v_role_city_list TY_CITY_DTL := TY_CITY_DTL();
v_user_role varchar2(4000);

BEGIN

v_customer_name := lower(Pi_customer_name);

IF Pi_location_type = 'COUNTRY' THEN
v_role_city_list := pkg_customer.Get_City_list_fn(Pi_geography_type => Pi_location_type,Pi_geography_code => Pi_country,Pi_effective_date => sysdate);
ELSIF Pi_location_type = 'REGION' THEN
v_role_city_list := pkg_customer.Get_City_list_fn(Pi_geography_type => Pi_location_type,Pi_geography_code => Pi_country,Pi_effective_date => sysdate);
ELSIF Pi_location_type = 'CITY' THEN
SELECT typ_city_dtl('CITY',column_value) BULK COLLECT INTO v_role_city_list FROM TABLE(CAST(in_list_char(Pi_country) AS chartabletype));
ELSIF Pi_location_type = 'TERRITORY' THEN  
select typ_city_dtl('CITY',dtl.location_code) BULK COLLECT INTO v_role_city_list from view_sp_loc_hrchy_dtl dtl
where dtl.territory_code in (select column_value from TABLE(CAST(in_list_char(Pi_country) AS chartabletype)));
END IF;

--Find the user roles
BEGIN
select LISTAGG(rm.ROLE_CODE, ',') WITHIN GROUP (ORDER BY rm.ROLE_CODE) 
into v_user_role
          from Um_User_Master          um,
               UM_USER_PRIVILEGE       up,
               um_role_master          rm
         where um.user_id = up.user_id
           and up.role_id = rm.role_id
           and user_name = Pi_user_name
           and um.ACTIVE = 'Y'
           and up.ACTIVE = 'Y'
           and rm.ACTIVE = 'Y';
EXCEPTION WHEN OTHERS THEN 
v_user_role := '';
END;

--Check if location is already passed. If not, Derive the user locations from user management and check against the incentive location defined
--pkg_customer.Get_member_locations_pr(Pi_application_code => Pi_application_code,Pi_user_name => Pi_user_name,Po_locations => V_COUNTRY_DTL);

--AGREEEMENT GRP ID , AGREEMENT GRP COUNTRY,AGREEMENT GRP STATUS
IF NVL(Pi_incentive_id,0) = 0  THEN
IF Pi_product_code<>'QBIZ'  OR Pi_product_code<>'BEYONDBUS' THEN

 IF nvl(Pi_is_product_level,'N')='N' THEN 

OPEN Po_output FOR

  select * from 
   ( select * from (select         inc_hdr_id, 
               source_type,
               source_reference,
               status,
               case 
                    when status='EXPIRED' then status 
                    when Pi_product_code='PLB' then  null 
                    when Pi_product_code<>'PLB' and  status='INITIAL' then 'INITIAL'
                    when Pi_product_code<>'PLB' and  status='PENDIING' then 'PENDING' 
                    when Pi_product_code<>'PLB' and  status='ACCEPTED' then 'PENDING'
                    when Pi_product_code<>'PLB' and  status='SUSPENDED' then 'PENDING' 
                    when Pi_product_code<>'PLB' and status='APPROVED' and task_pending_with<>'Not Applicable' 
                         then 'PENDING'
                    when Pi_product_code<>'PLB' and  status='TERMINATED' then 'TERMINATED' 
                    when Pi_product_code<>'PLB' and status='APPROVED' and task_pending_with='Not Applicable' 
                         and   effective_from>=trunc(sysdate)  then  'ACTIVE'      
                    when Pi_product_code<>'PLB' and status='APPROVED' and task_pending_with='Not Applicable' 
                         and  effective_to>=trunc(sysdate)  then  'ACTIVE'                     
                    when Pi_product_code<>'PLB' and  status='CANCELLED' then 'CANCELLED'  
                    when Pi_product_code<>'PLB' and status='APPROVED' and task_pending_with='Not Applicable' 
                         and effective_to<trunc(sysdate)  then  'EXPIRED' 
                    else status     END 
                   agreement_new_status ,
               sales_product_code,
               customer_type,
               customer_profile_id,
               customer_category,
               agreement_type,
               NVL(soto_agreement,'N') soto_agreement,
               --effective_from inc_from  --TFS 11012:,
               --effective_to  inc_to  --TFS 11012:,
               inc_from, --TFS 11012:
               inc_to,----TFS 11012:
               effective_from,
               effective_to,
               master_contract_number,
               created_by,
               created_date,
               last_modified_by,
               last_modified_date,
               promo_code,
               incentive_city,
               (case when (select count(1) from mst_city
                   where upper(CITY_NAME) = upper(incentive_city)
                   and upper(COUNTRY_CODE) = upper(incentive_country)
                   and rownum = 1) > 0 then
                   (select CITY_CODE from mst_city
                   where upper(CITY_NAME) = upper(incentive_city)
                   and upper(COUNTRY_CODE) = upper(incentive_country)
                   and rownum = 1)
                   else  NULL
                   end)   INCENTIVE_CITY_code ,
               incentive_country_desc AS incentive_country ,
               incentive_country_desc,
               promo_code_url,
               farebasis_code,
               ibe_office_id,
               tkt_instructions,
               fare_disp_entry,
               quote_disp_entry,
               tkt_acc_code,
               inc_location_basis,
               config_location_type,
               loc_modfn_allowed,
               master_deal_code,
               activity_id,
               task_classifier_code,
               inc_name,
               task_pending_with,
               task_pending_with_desc,
               master_track_code,
               RNK,
               tkt_agent_exists,
               customer_name,
               customer_code,
               cons_status,
               incentive_city inc_city_code, --Newly added for Rajesh on 11-NOV-2015
               agreement_group_id,
               group_country_code,
               group_country_code_desc,
               group_status,
               soto_master,
               approver_user,
               negative_growth,
               parent_inc_id , --Added by shabir on 21-JUL-2016
               miles_earned,
               miles_redeemed,
               miles_balance,
               miles_expiry,
               miles_expiry_date,
               membership_number_Odc AS membership_number,
               
               0 as MILES_ELIGIBLE,
               0 as MILES_NON_ELIGIBLE,
               0 as TOTAL_REVENUE,
             
               Industry_Description,
               CURRENT_TIER,
                CPName,
                CPEmail,
                 PAName,
                PAEmail,
                 TerminateReason,
               null retro_miles,
               null retro_period,
               Payout_Frequency,
               is_fixed_fund,
               is_super_plb,
               is_all_prodcut_Cap,
              case when status in ('CANCELLED','REJECTED') then null  else  round(initial_expected_rev,3) end  initial_expected_rev ,
               case when status in ('CANCELLED','REJECTED') then null  else  round(forecast_expected_rev,3) end forecast_expected_rev ,
               case when status in ('CANCELLED','REJECTED') then null  else  round(expected_payout,3) end expected_payout ,
               case when status in ('CANCELLED','REJECTED') then null  else  round(forecast_payout,3)  end forecast_payout ,
               case when status in ('CANCELLED','REJECTED') then null  else   round(max_payout,3)  end max_payout ,
               case when status in ('CANCELLED','REJECTED') then null  else   round(fixed_payout,3) end  fixed_payout ,
                case when  (Pi_product_code<>'PLB' or status in ('CANCELLED','REJECTED') )  then null 
                     else case when nvl(initial_expected_rev,0)=0 then null
                               else round(((nvl(forecast_expected_rev,0)-nvl(initial_expected_rev,0))/initial_expected_rev)*100,3)
                           end 
                end var_revenue,

                case when  (Pi_product_code<>'PLB' or status in ('CANCELLED','REJECTED') )  then null 
                     else case when nvl(expected_payout,0)=0 then null
                               else round(((nvl(forecast_payout,0)-nvl(expected_payout,0))/expected_payout)*100,3)
                           end 
                end var_payout,
                case when  (Pi_product_code<>'PLB' or status in ('CANCELLED','REJECTED') )  then null 
                     else case when nvl(initial_expected_rev,0)=0 then null                      
                              else round((expected_payout/initial_expected_rev)*100 ,3)
                           end 
                end initial_cos,
                 case when (Pi_product_code<>'PLB' or status in ('CANCELLED','REJECTED') )  then null 
                     else case when nvl(forecast_expected_rev,0)=0 then null                      
                              else round((forecast_payout/forecast_expected_rev)*100 ,3)
                 end 
                end revised_cos,
                 case when  (Pi_product_code<>'PLB' or status in ('CANCELLED','REJECTED') )  then null 
                     else round((forecast_expected_rev-forecast_payout),3)
                end qr_benefit,

                   case when  (Pi_product_code<>'PLB' or status in ('CANCELLED','REJECTED') )  then null 

                   else  case when (initial_expected_rev-expected_payout)=0 then 0 else 

                     round(((((round((forecast_expected_rev-forecast_payout),3)- round((initial_expected_rev-expected_payout),3))
                          / round((initial_expected_rev-expected_payout),3)))*100),2)

                          end 

                    end 
                 VAR_QR_BENEFIT_PERC ,
                case when has_overall='Y' then 

                                  (  select sum(val.measure_from*2/100)  from inc_rule_comp_value val , inc_rule_comp_period prd ,inc_rule_comp_hdr hdr,inc_rbd_products rbd

                                    where val.rule_comp_period_id=prd.rule_comp_period_id
                                    and hdr.rule_comp_hdr_id=prd.rule_comp_hdr_id
                                    and val.slab_number='1'
                                    and hdr.rbd_value=rbd.rbd_product_id
                                    and hdr.rule_header_id=inc_hdr_id
                                    and rbd.booking_product_code='PLBOVERALL')


              ELSE   (  select sum(val.measure_from*2/100)  from inc_rule_comp_value val , inc_rule_comp_period prd ,inc_rule_comp_hdr hdr,inc_rbd_products rbd

                                    where val.rule_comp_period_id=prd.rule_comp_period_id
                                    and hdr.rule_comp_hdr_id=prd.rule_comp_hdr_id
                                    and val.slab_number='1'
                                    and hdr.rbd_value=rbd.rbd_product_id
                                    and rbd.booking_product_code in ('PLBPREM','PLBECO')
                                    and hdr.rule_header_id=inc_hdr_id
                                    )

             END

         tier1_target,
           /* new changes for magiq */
         round(baseline_target,2) baseline_target,
          round(actual_revenue,2) actual_revenue,
         round(actual_revenue-baseline_target, 2) variance_rev,
         case when  actual_revenue=0 then 0  else round( (((actual_revenue-baseline_target)/ baseline_target)*100),2) end var_perc
         /* new changes for magiq */

          ,nvl(channel_type,(case when Pi_product_code='PLB' then 'FIT/Retail' end ))   channel_type
          ,wf_classifier_code --TFS11196  
          ,add_hdr_id  -- added for TFS1290 for addendum consolidation status 
          ,has_approval -- TFS15843 
          ,(select cnt 
             from(select h.inc_hdr_id,count(1) cnt from inc_add_hdr h 
                     where h.inc_hdr_id = t.inc_hdr_id
                    group by h.inc_hdr_id)) inc_add_cnt,
            --customer_code,
            CURRENCY,
            --task_pending_with,
            --(select stragg(th.description)
           -- from task_hdr th
           -- where th.task_code in (SELECT column_value FROM TABLE(CAST(in_list_char(task_pending_with) AS chartabletype))) 
           -- ) task_pending_with_desc,
            Addendum,
            Addendum_type,
            Addendum_status,
            Addendum_id,
            EXCEPTION_CODE,            
            EXCEPTION_TYPE,
            (select LISTAGG(e.DESCRIPTION, '~') WITHIN GROUP (ORDER BY e.CODE)   
            from mst_code_dtl e
            where e.CODE_TYPE IN ( 'INC_GLD_RL','INC_EXP')
            and e.CODE in (select * 
                         from TABLE(CAST(in_list_char(EXCEPTION_CODE_1) AS chartabletype)))) EXCEPTION_DESC,                                     
            EXCEPTION_DESC_TYPE,                          
            workflow_id ,
            is_reset  
            from (select hdr.inc_hdr_id,
               hdr.source_type,
               hdr.source_reference,
               hdr.status,
               hdr.sales_product_code,
               hdr.customer_type,
               hdr.customer_profile_id,
               hdr.customer_category,
               hdr.agreement_type,
               NVL(hdr.soto_agreement,'N') soto_agreement,
               hdr.effective_from inc_from,
               hdr.effective_to  inc_to,
               rag.effective_from,
               rag.effective_to,
                (select CD.DESCRIPTION from mst_code_dtl CD
                                where CD.CODE=   cp.industry_sector
                                 and rownum=1
                               )   Industry_Description,
                 CASE    (select ODCC.CURRENT_TIER from offer_deal_codes ODCC
                                where ODCC.INC_HDR_ID =   hdr.inc_hdr_id
                                 and rownum=1
                               ) WHEN 'EL' THEN 'Elevate' WHEN 'AC' THEN 'Accelerate' WHEN 'AS' THEN 'Ascent' ELSE (select ODCC.CURRENT_TIER from offer_deal_codes ODCC
                                where ODCC.INC_HDR_ID =   hdr.inc_hdr_id
                                 and rownum=1
                               ) END AS  CURRENT_TIER,
                                 ( SELECT * FROM ( SELECT CONCAT (  cond.first_name ,  CONCAT(' ', cond.last_name ))  FROM CONTACT_DETAILS cond  
                                
                               WHERE cond.customer_profile_id  = hdr.customer_profile_id AND cond.contact_type ='SMEADMIN'  ORDER BY cond.contact_detail_id DESC   ) WHERE   rownum =1 )  CPName
                               ,
                               ( SELECT * FROM ( SELECT CONCAT (  cond.first_name ,  CONCAT(' ', cond.last_name ))  FROM CONTACT_DETAILS cond  
                                
                               WHERE cond.customer_profile_id  = hdr.customer_profile_id AND (cond.contact_type ='PAADMIN' OR cond.contact_type ='PA')  ORDER BY cond.contact_detail_id DESC   ) WHERE   rownum =1 )  PAName
                              ,
                              
                              ( SELECT * FROM ( SELECT  CCM.COMMUNICATION_VALUE  FROM CONTACT_DETAILS cond  ,contact_communication CCM 
                                
                               WHERE cond.customer_profile_id  = hdr.customer_profile_id AND (cond.contact_type ='PAADMIN' OR cond.contact_type ='PA') AND cond.contact_detail_id =CCM.CONTACT_DETAIL_ID AND CCM.COMMUNICATION_TYPE ='EMAIL' ORDER BY cond.contact_detail_id DESC   ) WHERE   rownum =1 )  PAEmail
                              ,
                               ( SELECT * FROM ( SELECT  CCM.COMMUNICATION_VALUE  FROM CONTACT_DETAILS cond  ,contact_communication CCM 
                                
                               WHERE cond.customer_profile_id  = hdr.customer_profile_id AND (cond.contact_type ='SMEADMIN' ) AND cond.contact_detail_id =CCM.CONTACT_DETAIL_ID AND CCM.COMMUNICATION_TYPE ='EMAIL' ORDER BY cond.contact_detail_id DESC   ) WHERE   rownum =1 )  CPEmail,
                               
                              (SELECT * FROM  ( SELECT MSD.DESCRIPTION FROM INC_HDR IH ,Svc_Trx_Task_Plan TP , MST_CODE_DTL MSD

WHERE IH.Activity_Id  = TP.TRX_DTL_ID AND  IH.STATUS ='TERMINATED' AND IH.INC_HDR_ID = hdr.inc_hdr_id AND MSD.CODE = TP.Remarks   ) WHERE rownum =1)   AS TerminateReason,
                           
                               (SELECT ODCI.MEMBERSHIP_NUMBER FROM Offer_Deal_Codes  ODCI  WHERE ODCI.INC_HDR_ID  =hdr.inc_hdr_id and rownum =1) AS membership_number_Odc,
                                 
               rag.INCENTIVE_CURRENCY CURRENCY,
               (case when (select count(1) from inc_add_hdr h where  h.INC_HDR_ID = hdr.INC_HDR_ID) > 0 
                    then (select LISTAGG(h.ADD_NAME, '~') WITHIN GROUP (ORDER BY h.ADD_NAME)  
                          from inc_add_hdr h
                          where  h.INC_HDR_ID =hdr.INC_HDR_ID)
                    ELSE
                        NULL
                END        ) Addendum,
                (case when (select count(1) from inc_add_hdr h where  h.INC_HDR_ID = hdr.INC_HDR_ID) > 0 
                    then (select LISTAGG(h.ADD_TYPE, '~') WITHIN GROUP (ORDER BY h.ADD_NAME)   
                          from inc_add_hdr h
						  where h.INC_HDR_ID = hdr.INC_HDR_ID						  
                         )              
                    ELSE
                        NULL
                END        ) Addendum_type,

                (case when (select count(1) from inc_add_hdr h where  h.INC_HDR_ID = hdr.INC_HDR_ID) > 0 
                    then (select LISTAGG(h.STATUS, '~') WITHIN GROUP (ORDER BY h.ADD_NAME)   
                          from inc_add_hdr h
						  where h.INC_HDR_ID = hdr.INC_HDR_ID						  
                         )              
                    ELSE
                        NULL
                END        ) Addendum_status,
                (case when (select count(1) from inc_add_hdr h where  h.INC_HDR_ID = hdr.INC_HDR_ID) > 0 
                    then (select LISTAGG(h.ADD_HDR_ID, '~') WITHIN GROUP (ORDER BY h.ADD_NAME)   
                          from inc_add_hdr h
						  where h.INC_HDR_ID = hdr.INC_HDR_ID						  
                         )              
                    ELSE
                        NULL
                END        ) Addendum_id,  
                (CASE WHEN (select count(1)   
                            from  INC_EXCEPTIONS e 
                            where e.INC_HDR_ID = hdr.INC_HDR_ID) > 0 THEN
                       (select LISTAGG(e.EXCEPTION_CODE, '~') WITHIN GROUP (ORDER BY e.EXCEPTION_CODE,e.INC_EXCEPTION_ID)   
                            from  INC_EXCEPTIONS e 
                            where e.INC_HDR_ID = hdr.INC_HDR_ID)
                      ELSE
                            NULL
                 END) EXCEPTION_CODE,
                 (CASE WHEN (select count(1)   
                            from  INC_EXCEPTIONS e 
                            where e.INC_HDR_ID = hdr.INC_HDR_ID) > 0 THEN
                       (select LISTAGG(e.EXCEPTION_CODE, ',') WITHIN GROUP (ORDER BY e.EXCEPTION_CODE,e.INC_EXCEPTION_ID)   
                            from  INC_EXCEPTIONS e 
                            where e.INC_HDR_ID = hdr.INC_HDR_ID)
                      ELSE
                            NULL
                 END) EXCEPTION_CODE_1,
                 (CASE WHEN (select count(1)   
                            from  INC_EXCEPTIONS e 
                            where e.INC_HDR_ID = hdr.INC_HDR_ID) > 0 THEN
                       (select LISTAGG(decode(e.ADD_HDR_ID,'','MAIN','ADD'), '~') WITHIN GROUP (ORDER BY e.EXCEPTION_CODE,e.INC_EXCEPTION_ID)   
                            from  INC_EXCEPTIONS e 
                            where e.INC_HDR_ID = hdr.INC_HDR_ID)
                      ELSE
                            NULL
                 END) EXCEPTION_DESC_TYPE,
                 (CASE WHEN (select count(1)   
                            from  INC_EXCEPTIONS e 
                            where e.INC_HDR_ID = hdr.INC_HDR_ID) > 0 
                      THEN (select LISTAGG(e.EXCEPTION_TYPE, '~') WITHIN GROUP (ORDER BY e.EXCEPTION_CODE)   
                            from  INC_EXCEPTIONS e 
                            where e.INC_HDR_ID = hdr.INC_HDR_ID)
                      ELSE
                            NULL
                 END) EXCEPTION_TYPE,
               hdr.master_contract_number,
               hdr.created_by,
               hdr.created_date,
               hdr.last_modified_by,
               hdr.last_modified_date,
               hdr.promo_code,
               (select NVL(mc.city_name, ca.city)
                  from customer_address ca, mst_city mc
                 where ca.customer_profile_id = cp.customer_profile_id
                   and ca.valid = 'Y'
                   and ca.address_type = 'LOCATION'
                   and rownum = 1
                   and mc.city_code(+) = ca.city) incentive_city,                   
               (select COUNTRY_CODE
                  from customer_address ca
                 where ca.customer_profile_id = cp.customer_profile_id
                   and ca.valid = 'Y'
                   and ca.address_type = 'LOCATION'
                   and rownum = 1) incentive_country,   
               (select mc.COUNTRY_NAME
                  from customer_address ca,MST_COUNTRY mc
                 where ca.customer_profile_id = cp.customer_profile_id
                   and ca.valid = 'Y'
                   and ca.address_type = 'LOCATION'
                   and mc.COUNTRY_CODE = ca.COUNTRY_CODE
                   and rownum = 1) incentive_country_desc,
               (select case when count(0) > 0 then 'Y' else 'N' end
                  from inc_process_dtl pd
                 where pd.inc_hdr_id = hdr.inc_hdr_id
                ) has_approval, -- TFS15843 
               hdr.promo_code_url,
               hdr.farebasis_code,
               hdr.ibe_office_id,
               hdr.tkt_instructions,
               hdr.fare_disp_entry,
               hdr.quote_disp_entry,
               hdr.tkt_acc_code,
               hdr.inc_location_basis,
               hdr.config_location_type,
               hdr.loc_modfn_allowed,
               hdr.master_deal_code,
               hdr.activity_id,
               hdr.task_classifier_code,
               hdr.inc_name,
               hdr.task_pending_with,
               (select isa.deal_code
                  from inc_associated_accounts isa
                 where isa.inc_hdr_id = hdr.inc_hdr_id
                   and isa.master_agreement = 'Y') master_track_code,
               /*(select th.description
                  from task_hdr th
                 where th.task_code = nvl( add1.task_pending_with, hdr.task_pending_with) -- added for TFS1290 for addendum consolidation status 
                   and rownum = 1) task_pending_with_desc,*/
                 (case when hdr.task_pending_with is null
                     then   NULL
                     when hdr.task_pending_with = 'FAREWTHDRW'
                     then 'FARE WITHDRAW'
                     when upper(hdr.task_pending_with) = 'CMS INTEGRATION' THEN
					   hdr.task_pending_with
					 else
                     (select stragg(rm.ROLE_NAME) 
                     from um_role_master rm
                     where rm.role_code  in (SELECT column_value FROM TABLE(CAST(in_list_char(hdr.task_pending_with) AS chartabletype))) 
                    )
                     end) task_pending_with_desc,  
               RANK() OVER(ORDER BY hdr.created_date desc) as RNK,
               (select decode(COUNT(1),0,'N','Y') from inc_ticketing_agents ita where ita.inc_hdr_id = hdr.inc_hdr_id) tkt_agent_exists,
               cp.customer_name,
               cp.customer_code,
               hdr.cons_status,
               hdr.incentive_city inc_city_code, --Newly added for Rajesh on 11-NOV-2015
               rag.agreement_group_id,               
               rag.country_code  group_country_code,
                (select COUNTRY_NAME from MST_COUNTRY mc
               where mc.country_code = rag.country_code
               and rownum =1) group_country_code_desc,
               --ag.country_code group_country_code,
               rag.status group_status,
               NVL(rag.master_agreement,'Y') soto_master,
               rag.approver_user,
               (select decode(COUNT(1), 0, 'N', 'Y')
                  from inc_rule_comp_hdr rch, inc_rule_comp_whatif wht
                 where rch.rule_header_id = hdr.inc_hdr_id
                   and wht.rule_comp_hdr_id = rch.rule_comp_hdr_id
                   and wht.period_from >= hdr.effective_from
                   and wht.period_to <= hdr.effective_to
                   and wht.growth_perc < 0
                ) negative_growth,
               hdr.parent_inc_id , --Added by shabir on 21-JUL-2016
               miles.miles_earned,
               miles.miles_redeemed,
               miles.miles_balance,
               miles.miles_expiry,
               miles.miles_expiry_date,
               miles.membership_number,
                
               null retro_miles,
               null retro_period,
               case when Pi_product_code<>'PLB' then null 
                              else (select mst.description from inc_payout_types pay,inc_types typ, inc_models mdl , 
(select code ,                      description from mst_code_dtl where code_type = 'INCPAYFREQ') mst
                                    where pay.inc_type_id=typ.inc_type_id
                                    and typ.inc_model_id=mdl.inc_model_id
                                    and mdl.agreement_group_id=rag.agreement_group_id
                                    and pay.payment_frequency_type=mst.code
                                    and rownum=1) 
                          end Payout_Frequency ,
                case when Pi_product_code<>'PLB' then null 
                            else  (select decode( count(1),0,'N','Y')   from inc_types typ, inc_models mdl
                                    where typ.inc_model_id=mdl.inc_model_id
                                    and mdl.agreement_group_id=rag.agreement_group_id
                                    and typ.incentive_type<>'BASIC')
                         end is_fixed_fund,
                   case when Pi_product_code<>'PLB' then null 
                            else  ( case when hdr.parent_inc_id is null then 'N'
                                                else 'Y'
                                                end ) end  is_super_plb ,
                   case when Pi_product_code<>'PLB' then null 
                              else ( select decode( count(1),0,'Y','N')   from inc_rule_comp_value val,inc_rule_comp_period prd ,inc_rule_comp_hdr rul ,inc_payout_types pay ,
                                          inc_types typ, inc_models mdl
                                          where val.rule_comp_period_id=prd.rule_comp_period_id
                                          and prd.rule_comp_hdr_id=rul.rule_comp_hdr_id
                                          and rul.payout_type_id=pay.payout_type_id
                                          and pay.inc_type_id=typ.inc_type_id
                                          and typ.inc_model_id=mdl.inc_model_id
                                          and mdl.agreement_group_id=rag.agreement_group_id
                                          and typ.incentive_type='BASIC'
                                          and measure_to is null ) end is_all_prodcut_Cap,
                    case when Pi_product_code<>'PLB' then null 
                         else   pkg_incentive.Get_exch_rate_fn(rag.incentive_currency,
                                                        hdr.effective_from,
                                                        Pi_currency_code,
                                                      /* case when hdr.status='TERMINATED' then
                                                     case when hdr.parent_inc_id is not null then 0
                                                                   else nvl(rag.forecast_base_rev, 0)
                                                                end
                                                         else
                                                              case when hdr.parent_inc_id is null
                                                                then  nvl(rag.expected_base_revenue, 0)
                                                               else  hdr.incremental_revenue
                                                               end
                                                          end*/
                                                          nvl(rag.expected_base_revenue, 0)
                                                          )
                                   end   initial_expected_rev,
                         case when Pi_product_code<>'PLB' then null 
                         else   pkg_incentive.Get_exch_rate_fn(rag.incentive_currency,
                                                        hdr.effective_from,
                                                        Pi_currency_code,
                                                                   (select case
                                                                       when inc.status = 'TERMINATED' then

                                                                        case
                                                                          when inc.parent_inc_id is not null then
                                                                           0
                                                                          else
                                                                           nvl(grp.forecast_base_rev, 0)
                                                                        end
                                                                       else
                                                                        case
                                                                          when INC.parent_inc_id is not null then
                                                                           (select case
                                                                                        when forecast_base_rev is not null then  0
                                                                                             else INC.incremental_revenue
                                                                                    end
                                                                                 from inc_agreement_group GRP_PARENT 
                                                                             where inc_hdr_id = INC.parent_inc_id)
                                                                          else
                                                                           nvl(nvl(GRP.forecast_base_rev, GRP.expected_base_revenue), 0)
                                                                        end
                                                                     end                                                                           
                                                                from inc_agreement_group grp, inc_hdr inc
                                                               where inc.inc_hdr_id = hdr.inc_hdr_id
                                                                 and grp.inc_hdr_id = inc.inc_hdr_id
                                                                 ))
                                   end   forecast_expected_rev,
                          case when Pi_product_code<>'PLB' then null 
                           else   (select nvl( (sum(pkg_incentive.Get_exch_rate_fn(rag.incentive_currency,
                                                        hdr.effective_from,
                                                        Pi_currency_code,
                                                        (case when rul.add_hdr_id is null then rul.expected_payout
                                                             when (select count(1) from inc_add_hdr addr 
                                                                   where addr.add_hdr_id=rul.add_hdr_id
                                                                   and addr.status='CANCELLED' )>0 then 0
                                                             else rul.expected_payout
                                                            end)
                                                        ))),0)
                                                        from inc_rule_comp_hdr rul
                                                        where rul.rule_header_id=hdr.inc_hdr_id)
                                   end  expected_payout, 
                            case when Pi_product_code<>'PLB' then null 

                           else  (select  nvl( (sum(pkg_incentive.Get_exch_rate_fn(rag.incentive_currency,
                                                        hdr.effective_from,
                                                        Pi_currency_code,
                                                        (case when rul.add_hdr_id is null then rul.forecast_payout
                                                             when (select count(1) from inc_add_hdr addr 
                                                                   where addr.add_hdr_id=rul.add_hdr_id
                                                                   and addr.status='CANCELLED' )>0 then 0
                                                             else rul.forecast_payout
                                                            end)
                                                        ))),0)
                                                        from inc_rule_comp_hdr rul
                                                        where rul.rule_header_id=hdr.inc_hdr_id)
                                   end  forecast_payout  ,
                              case when Pi_product_code<>'PLB' then null 
                           else  (select  nvl( (sum(pkg_incentive.Get_exch_rate_fn(rag.incentive_currency,
                                                        hdr.effective_from,
                                                        Pi_currency_code,
                                                        rul.expected_payout
                                                        ))),0)
                                                        from inc_rule_comp_hdr rul
                                                        where rul.rule_header_id=hdr.inc_hdr_id
                                                        and rul.value_type='VALUE'
                                                        )
                                   end  fixed_payout  ,            

                           case when Pi_product_code<>'PLB' then null 
                           else   case when hdr.status='TERMINATED' THEN   (select  nvl( (sum(pkg_incentive.Get_exch_rate_fn(rag.incentive_currency,
                                                        hdr.effective_from,
                                                        Pi_currency_code,
                                                        rul.forecast_payout
                                                        ))),0)
                                                        from inc_rule_comp_hdr rul
                                                        where rul.rule_header_id=hdr.inc_hdr_id)  else
                                (select  nvl( (sum(pkg_incentive.Get_exch_rate_fn(rag.incentive_currency,
                                                        hdr.effective_from,
                                                        Pi_currency_code,
                                                        rul.max_payout
                                                        ))),0)
                                                        from inc_rule_comp_hdr rul
                                                        where rul.rule_header_id=hdr.inc_hdr_id) end 
                                   end  max_payout     ,
                                 ( select decode( count(1),'0','N','Y')  from inc_rule_comp_value val , inc_rule_comp_period prd ,inc_rule_comp_hdr rul,inc_rbd_products rbd
                                    where val.rule_comp_period_id=prd.rule_comp_period_id
                                    and rul.rule_comp_hdr_id=prd.rule_comp_hdr_id
                                    and val.slab_number='1'
                                    and rul.rbd_value=rbd.rbd_product_id
                                    and rul.rule_header_id=hdr.inc_hdr_id
                                    and rbd.booking_product_code='PLBOVERALL'
                                   ) has_overall

                                    /* new changes for magiq */
                                   ,case when hdr.sales_product_code='MAGIQ' then (select  nvl( (sum(pkg_incentive.Get_exch_rate_fn(rag.incentive_currency,
                                                        hdr.effective_from,
                                                        Pi_currency_code,
                                                        grp1.expected_base_revenue
                                                        ))),0)
                                                        from inc_agreement_group grp1
                                                        where grp1.inc_hdr_id=hdr.inc_hdr_id and grp1.master_agreement='Y') 
                                                        else null end
                                                        baseline_target 
                                      ,case when hdr.sales_product_code='MAGIQ' then (select  nvl( (sum(pkg_incentive.Get_exch_rate_fn(rag.incentive_currency,
                                                        hdr.effective_from,
                                                        Pi_currency_code,
                                                        grp1.forecast_base_rev
                                                        ))),0)
                                                        from inc_agreement_group grp1
                                                        where grp1.inc_hdr_id=hdr.inc_hdr_id and grp1.master_agreement='Y') 
                                                        else null end
                                                        actual_revenue   

                                     /* new changes for magiq */
                                     ,

                            ( select chnl_mst.description from tbl_glxy_agent_custom_grp agent_chnl, (select * from mst_code_dtl 
                                where code_type='CHNL_TYPE') chnl_mst                           
                               where agent_chnl.customer_profile_id=hdr.customer_profile_id
                               and agent_chnl.group_type='CHNL_TYPE'  and 
                                agent_chnl.group_code=chnl_mst.code and rownum=1
                               )   channel_type 
                              ,rag.wf_classifier_code --TFS11196      
                              , add1.add_hdr_id    -- added for TFS1290 for addendum consolidation status 
                              ,rag.workflow_id
                              ,hdr.is_reset
                             from inc_hdr hdr, customer_profile cp,inc_agreement_group rag, (
                select sum(miles.miles_earned) miles_earned , sum(miles.miles_redeemed) miles_redeemed ,sum(miles.miles_balance) miles_balance ,sum(miles.miles_expiry) miles_expiry
                ,miles.miles_expiry_date , hdr.inc_hdr_id, deal.deal_code,deal.membership_number from offer_deal_codes deal , inc_hdr hdr,qbiz_miles_info miles
                where deal.inc_hdr_id=hdr.inc_hdr_id
                and miles.track_code=deal.deal_code
                and  miles.membership_no=deal.membership_number
                group by miles_expiry_date , hdr.inc_hdr_id, deal.deal_code,deal.membership_number 
                   ) miles ,(select  inc_hdr_id ,cons_status , decode(task_pending_with,'NA','Not Applicable',task_pending_with)  task_pending_with ,  LISTAGG(add_hdr_id, ',') WITHIN GROUP (ORDER BY add_hdr_id)  add_hdr_id
                             from inc_add_hdr  a   
                             where a.add_type='RULES'    
                              and cons_status<>'COMPLETED'  
                              and a.status<>'CANCELLED'---TFS15561                   
                              group by  inc_hdr_id ,cons_status ,decode(task_pending_with,'NA','Not Applicable',task_pending_with)  ) add1 -- added for TFS1290 for addendum consolidation status 
         where hdr.sales_product_code = Pi_product_code
           and hdr.customer_type = Pi_customer_type
           and upper(hdr.inc_name) like '%'|| upper(Pi_incentive_name)|| '%'
           --and  NVL(hdr.cons_status,'#') = NVL(Pi_cons_status,NVL(hdr.cons_status,'#'))  -- added for TFS1290 for addendum consolidation status            
          and ( NVL(hdr.cons_status,'#') = NVL(Pi_cons_status,NVL(hdr.cons_status,'#')) -- added for TFS1290 for addendum consolidation status 
            or (NVL(add1.cons_status,'#') = NVL(Pi_cons_status,NVL(add1.cons_status,'#'))) ) -- added for TFS1290 for addendum consolidation status 
           and (Pi_status is null or hdr.status in (SELECT column_value FROM TABLE(CAST(in_list_char(Pi_status) AS chartabletype))))
           and rag.inc_hdr_id = hdr.inc_hdr_id
           and hdr.inc_hdr_id=miles.inc_hdr_id(+)
           and hdr.inc_hdr_id=add1.inc_hdr_id(+) -- added for TFS1290 for addendum consolidation status 
                     --and NVL(rag.master_agreement,'N') = NVL(Pi_soto_ind,NVL(rag.master_agreement,'N'))
           --and (Pi_soto_ind is null or Pi_soto_ind = NVL(rag.master_agreement,'N')  )
           and NVL(rag.master_agreement,'Y') = decode(NVL(Pi_soto_ind,'N'),'N','Y','Y','N')
           and (Pi_group_status is null or rag.status in (SELECT column_value FROM TABLE(CAST(in_list_char(Pi_group_status) AS chartabletype))))
           and cp.customer_profile_id = hdr.customer_profile_id
           and hdr.source_type = NVL(Pi_Source, hdr.source_type)
           and (NVL(Pi_soto_ind,'N') = 'Y' or (NVL(Pi_soto_ind,'N') = 'N' and rag.country_code = hdr.incentive_country))  --SOTO agreements are controlled through country code. by shabir on 27-JAN-2016 based on the discussion with Rajesh
           and (v_customer_name is null or lower(cp.customer_name) LIKE '%'|| v_customer_name || '%')
           and trunc(hdr.created_date) between trunc(NVL(Pi_created_from,'01-JAN-2000')) and trunc(NVL(Pi_created_to,'31-DEC-2099'))
--           and (NVL(Pi_soto_ind,'N') = 'Y' or trunc(hdr.created_date) between trunc(NVL(Pi_created_from,'01-JAN-2000')) and trunc(NVL(Pi_created_to,'31-DEC-2099')))
--           and (NVL(Pi_soto_ind,'N') = 'N' or trunc(rag.created_date) between trunc(NVL(Pi_created_from,'01-JAN-2000')) and trunc(NVL(Pi_created_to,'31-DEC-2099')))
           and NVL(hdr.master_contract_number, '##') = NVL(Pi_contract_number, NVL(hdr.master_contract_number, '##'))
           and NVL(hdr.promo_code, '##') = NVL(Pi_promo_code, NVL(hdr.promo_code, '##'))
           and (NVL(Pi_soto_ind,'N') = 'Y' or (NVL(Pi_soto_ind,'N') = 'N' and rag.add_hdr_id is null))    --Added by shabir on 27-JAN-2016
           --and NVL(hdr.incentive_country, '#') = DECODE(Pi_country,'ALL',NVL(hdr.incentive_country, '#'),null,NVL(hdr.incentive_country, '#'),Pi_country)
          -- and NVL(rag.country_code, '#') = DECODE(Pi_country,'ALL',NVL(rag.country_code, '#'),null,NVL(rag.country_code, '#'),Pi_country)
             and 
            ((NVL(Pi_location_type,'NETWORK') = 'NETWORK') 
            OR ( NVL(Pi_soto_ind,'N') = 'Y'
                  and rag.country_code in (SELECT column_value FROM TABLE(CAST(in_list_char(Pi_country) AS chartabletype)))
                  and rag.MASTER_AGREEMENT = 'N' 
                     )
          /* OR ( NVL(Pi_soto_ind,'N') = 'Y'
                  and rag.country_code in (SELECT column_value FROM TABLE(CAST(in_list_char(Pi_country) AS chartabletype)))
                     ) */
              or  ( (NVL(Pi_soto_ind,'N') = 'N')  and hdr.incentive_city in (select city_code from TABLE(v_role_city_list)))

             ) --Changes done for TFS14095   
           and  (NVL(Pi_pending_with,'ALL') = 'ALL'  
                 OR
                 (instr(hdr.task_pending_with,Pi_pending_with )> 0  or
                  instr(Pi_pending_with ,hdr.task_pending_with)> 0
                  )
                 OR
                 hdr.task_pending_with in (SELECT column_value FROM TABLE(CAST(in_list_char(Pi_pending_with) AS chartabletype)))
                )
           and ( ( hdr.sales_product_code<>  'PLB' and (trunc(hdr.effective_to/*hdr.effective_from*/) between trunc(NVL(Pi_inc_from,'01-JAN-2000')) and trunc(NVL(Pi_inc_to,'31-DEC-9999'))
                or trunc(hdr.effective_from) between trunc(NVL(Pi_inc_from,'01-JAN-2000')) and trunc(NVL(Pi_inc_to,'31-DEC-9999'))
                ) )
                or (( trunc(hdr.effective_from) >= trunc(NVL(Pi_inc_from,'01-JAN-2000')) 
                    and  trunc(hdr.effective_to) <= trunc(NVL(Pi_inc_to,'31-DEC-9999'))
                   ) 
                   or (hdr.sales_product_code=  'PLB'
                    and to_char(to_char(Pi_inc_from,'DDMM'))='0104'
                    and to_char(to_char(Pi_inc_to,'DDMM'))='3103'
                    and trunc(hdr.effective_from)=to_date('01-01-'|| to_char(Pi_inc_from,'YYYY'),'DD-MM-YYYY')
                    and trunc(hdr.effective_to)=to_date('31-12-'|| to_char(Pi_inc_from,'YYYY'),'DD-MM-YYYY')
                   )
                  )
                )
           and NVL(hdr.incentive_city,'#') = NVL(Pi_inc_city,NVL(hdr.incentive_city,'#'))
           and (NVL(Pi_payout_frequency,'ALL') = 'ALL' or exists (select 1 from inc_models im,inc_types ict,inc_payout_types ipt where im.agreement_group_id = rag.agreement_group_id and ict.inc_model_id = im.inc_model_id and ipt.inc_type_id = ict.inc_type_id and ipt.payment_frequency_type = Pi_payout_frequency))
           and (Pi_deal_code is null or exists
                (select 1
                   from inc_associated_accounts isa
                  where isa.inc_hdr_id = hdr.inc_hdr_id
                    and isa.deal_code = Pi_deal_code))
          and(((Pi_soto_ind = 'Y' and pi_soto_loc_search = 'Y' 
                and  rag.COUNTRY_CODE in (SELECT column_value FROM TABLE(CAST(in_list_char(NVL(pi_soto_inc_cntry,rag.COUNTRY_CODE)) AS chartabletype)))
                and rag.MASTER_AGREEMENT = 'N')
            or Pi_soto_ind = 'N' )   
          OR  ((Pi_soto_ind = 'Y' and pi_soto_loc_search = 'N' and  hdr.INCENTIVE_COUNTRY in (SELECT column_value FROM TABLE(CAST(in_list_char(NVL(pi_country,hdr.incentive_country)) AS chartabletype)))
                and rag.COUNTRY_CODE in (SELECT column_value FROM TABLE(CAST(in_list_char(NVL(pi_soto_inc_cntry,rag.COUNTRY_CODE)) AS chartabletype)))
                and rag.MASTER_AGREEMENT = 'N')
            or Pi_soto_ind = 'N'
               ))  
          and  (  (Pi_requested_by_me IS NULL
                     or
                     (Pi_requested_by_me = 'Y'
                     AND hdr.created_by = pi_user_name))
                 AND
                    (Pi_approved_by_me IS NULL
                     or
                     (Pi_approved_by_me = 'Y' and
                     exists (
                     select 1 
                     from wf_approval_history wah,inc_agreement_group iag
                     where wah.wf_request_id = iag.workflow_id
                     and iag.inc_hdr_id = hdr.inc_hdr_id
                     and wah.actioned_by = Pi_user_name
                     and wah.ACTION_CODE = 'APPROVE'
                     and wah.status= 'APPROVED'
                     )
                     ))        
                 )
           /*and exists (select 1
                  from TABLE(V_COUNTRY_DTL) t
                 where (t.country_code = rag.country_code OR
                       t.country_code = 'ALL'))*/
                       ) t   ) tab where (pi_agreement_status is null 
                        or agreement_new_status in (SELECT column_value FROM TABLE(CAST(in_list_char(pi_agreement_status) AS chartabletype)))) )
     where rnk <= (pi_page_number * pi_page_size) AND rnk > (pi_page_number - 1) * pi_page_size   ;

    
    END IF;
 
END IF; 
 
END IF;
END Incentive_BB_search_pr;

