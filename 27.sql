


 SELECT c.*,
  mrs.MR_Selected_Num as MR_code,
  mrs.MR_Selected_LgAdr1 as MR_addr1,
  mrs.MR_Selected_LgAdr2 as MR_addr2,
  mrs.MR_Selected_LgAdr3 as MR_addr3,
  mrs.MR_Selected_LgAdr4 as MR_addr4,
  mrs.MR_Selected_CP as MR_zip,
  mrs.MR_Selected_Ville as MR_city,
  mrs.MR_Selected_Pays as MR_country,
  MAX(o.id_order) as order_ID
FROM lpt_orders o
JOIN lpt_customer c ON (c.id_customer=o.id_customer)
LEFT JOIN lpt_mr_selected mrs ON (mrs.id_order = o.id_order)

GROUP BY

 c.id_customer
