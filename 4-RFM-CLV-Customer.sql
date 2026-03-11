########################################################################################################
## Create "RFM" Table ##

create table RFM_Customer (
CustomerID bigint primary key,
Recency int,
Frequency int,
Monetary decimal(12,2) , 
R_Score int,
F_Score int,
M_Score int,
RFM_Segment varchar(50) 
);


#2011-12-09 

insert into RFM_Customer (CustomerID, Recency, Frequency, Monetary)
select 
   CustomerID,
   datediff('2011-12-09', max(InvoiceDate)),
   count(distinct Invoice),
   sum(Quantity * Price)
from raw
group by CustomerID;
   

with RFM_Stats as (
   select CustomerID,
		  CASE
		   WHEN Recency <= 30 THEN 5
           WHEN Recency <= 60 THEN 4
		   WHEN Recency <= 90 THEN 3
		   WHEN Recency <= 120 THEN 2
           ELSE 1
          END AS R_Score,
		  CASE
           WHEN Frequency >= 120 THEN 5   
           WHEN Frequency >= 60 THEN 4   
		   WHEN Frequency >= 30 THEN 3   
           WHEN Frequency >= 15 THEN 2    
		   ELSE 1
          END AS F_Score ,
		  CASE
           WHEN Monetary >= 200000 THEN 5
           WHEN Monetary >= 90000 THEN 4
           WHEN Monetary >= 40000 THEN 3
           WHEN Monetary >= 20000 THEN 2
           ELSE 1
          END AS M_Score
	from  RFM_Customer)
update RFM_Customer R
join RFM_Stats A
on R.CustomerID = A.CustomerID
set 
R.R_Score = A.R_Score ,
R.F_Score = A.F_Score ,
R.M_Score = A.M_Score ;


update RFM_Customer
set 
RFM_Segment = 
   case 
     when R_Score >= 4 and F_Score >= 4 and M_Score >= 4  then 'VIP'
     when R_Score >= 4 and F_Score >= 3  then 'Loyal'
     when R_Score = 5 and F_Score = 1  then 'New'
     when R_Score <=3 and F_Score >= 3 and M_Score >= 3  then 'At_Risk'
     when R_Score = 1 and F_Score = 1 and M_Score <= 2   then 'Lost'
     else 'Regular'
	end
WHERE CustomerID <> 0;

UPDATE RFM_Customer
SET RFM_Segment = 'Unknown_Customer'
WHERE CustomerID = 0;
 
SELECT *
FROM RFM_Customer;


#####################################################################################
########################################################################################################
## Create "CLV" Table ##

create table CLV_Customer (
CustomerID bigint primary key,
Total_Orders bigint,
AOV decimal(12,4),
PF decimal(12,4),
CL_LifeSpan_Days decimal(12,3),
Estimated_CLV decimal(14,4),
CLV_Segment varchar(50)
);



insert into CLV_Customer (CustomerID)
select distinct CustomerID
from raw ;

with Customer_Stats as (
   select CustomerID,
          count(distinct invoice) as Total_Orders,
		  round(sum(Quantity * Price) / nullif(count(distinct invoice),0),4) as AOV,
          datediff(Max(InvoiceDate),Min(InvoiceDate)) as LifeSpan_Days  
   from raw
   group by CustomerID )
update CLV_Customer C
join Customer_Stats S
on C.CustomerID = S.CustomerID
set 
C.Total_Orders = S.Total_Orders,
C.AOV = S.AOV , 
C.PF = round( S.Total_Orders / GREATEST(S.LifeSpan_Days, 1) ,4) ,
C.CL_LifeSpan_Days = S.LifeSpan_Days ,
C.Estimated_CLV = round( S.AOV * ( S.Total_Orders / GREATEST(S.LifeSpan_Days, 1) ) * GREATEST(S.LifeSpan_Days, 1) ,4)
;
select * from CLV_Customer ; 

select CustomerID from CLV_Customer
where PF = 'null' ; 

select CustomerID, Estimated_CLV from CLV_Customer
order by Estimated_CLV desc ; 

update CLV_Customer
set CLV_Segment =
  case
    when Estimated_CLV >= 100000 then 'High_CLV'
    when Estimated_CLV >= 20000 then 'Medium_CLV'
    else 'Low_CLV'
  end ;
  
UPDATE CLV_Customer
SET CLV_Segment = 'Unknown_Customer'
WHERE CustomerID = 0;


select * from CLV_Customer 
order by Estimated_CLV desc;

########################################################################################################
## Create "RFM" with "CLV" TABLE ##

create table RFM_CLV_Customer (
CustomerID bigint primary key,
RFM_Code bigint,
RFM_Segment varchar(50),
Estimated_CLV decimal(14,4),
CLV_Segment varchar(50),
Customer_Value_Segment VARCHAR(50)
);

insert into RFM_CLV_Customer (CustomerID, RFM_Code, RFM_Segment, Estimated_CLV, CLV_Segment)
select
  R.CustomerID,
  concat(R_Score,F_Score,M_Score),
  R.RFM_Segment,
  C.Estimated_CLV,
  C.CLV_Segment
from RFM_Customer R
left join CLV_Customer C
on R.CustomerID = C.CustomerID ;

update RFM_CLV_Customer
set Customer_Value_Segment = 
  case 
    when RFM_Segment = 'Vip' and CLV_Segment = 'High_CLV' then 'Champions'
    when RFM_Segment in ('Vip','Loyal') and CLV_Segment = 'Medium_CLV' then 'High_Loyalty'
    when RFM_Segment = 'At_Risk' and CLV_Segment = 'High_CLV' then 'High_Value_At_Risk'
    when RFM_Segment = 'New' and CLV_Segment in ('High_CLV','Medium_CLV') then 'Promising_New'
    when RFM_Segment = 'Lost' and CLV_Segment = 'Low_CLV' then 'Low_Priority'
    else 'Regular'
  End ;

UPDATE RFM_CLV_Customer
SET Customer_Value_Segment = 'Unknown_Customer'
WHERE CustomerID = 0;


select * from RFM_CLV_Customer;

select * from RFM_CLV_Customer
where Customer_Value_Segment = 'High_Value_At_Risk' ;
