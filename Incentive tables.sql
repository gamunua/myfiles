-- Incentive tables 


SELECT CA.ADDRESS_TYPE, AG.CATEGORY,Ag.Expected_Base_Revenue, IH.INC_HDR_ID, CC.COMMUNICATION_VALUE,CC.COMMUNICATION_TYPE, CD.Contact_Type, CP.CUSTOMER_NAME,CA.ADDRESS_TYPE , CA.ADDRESS_LINE1,CA.CITY, ih.*, ih.status, ODC.DEAL_CODE,ODC.INC_HDR_ID 
FROM  Offer_Deal_Codes  ODC  
inner JOIN Account_Subscriptions ACCS ON ODC.ACCOUNT_SUBSCRIPTION_ID = ACCS.ACCOUNT_SUBSCRIPTION_ID
inner join Inc_Hdr  ih on ODC.INC_HDR_ID  = IH.INC_HDR_ID  
Inner Join Customer_Profile   CP on CP.CUSTOMER_PROFILE_ID  = IH.CUSTOMER_PROFILE_ID
Inner JOin Customer_Address  CA ON CA.CUSTOMER_PROFILE_ID  = CP.CUSTOMER_PROFILE_ID
Inner JOin  Contact_Details  CD ON CD.CUSTOMER_PROFILE_ID  =CP.CUSTOMER_PROFILE_ID
Inner join Contact_Communication  CC ON CC.CONTACT_DETAIL_ID  =CD.CONTACT_DETAIL_ID
Inner join inc_agreement_group AG ON AG.INC_HDR_ID  = IH.INC_HDR_ID
WHERE ODC.DEAL_CODE  ='INCH5'  AND CD.Contact_Type  = 'SMEADMIN';

inc_agreement_group  - one to many
--INCBH


-- one to many inc_ticketing_agents

SELECT ITA.INC_HDR_ID, CP.CUSTOMER_NAME ,ITA.AGENT_PROFILE_ID FROM inc_ticketing_agents ITA
INNER JOIN Customer_Profile  CP ON CP.CUSTOMER_PROFILE_ID  = ITA.AGENT_PROFILE_ID
WHERE ITA.INC_HDR_ID  = '48346'  order by 1 desc


-- addendum  one to many

SELECT * FROM INC_ADD_HDR AH  WHERE AH.INC_HDR_ID   = '48357'  ADD_TYPE  as foreign key with master table MST
 

SELECT * FROM Mst_Codes_Master  MM WHERE MM.CODE_TYPE  = 'ADDENDMTYPE' ;

SELECT * FROM Mst_Code_Dtl  CDD where CDD.CODE_TYPE  = 'ADDENDMTYPE'


--SELECT * FROM Mst_System_Parameters  P order by 1 desc


SELECT * FROM INC_AGENT_PORTAL_ACCESS -- link with inc_ticketing_agents  contact_detail_id with contact details

SELECT * FROM  inc_agreement_group  order by 1 desc

--one to many
SELECT * FROM INC_ASSOCIATED_ACCOUNTS  ORDER BY 1 Desc  
