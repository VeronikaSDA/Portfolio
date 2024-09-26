# History of granted loans
# Write a query that prepares a summary of the granted loans in the following dimensions:
#year, quarter, month,
#year, quarter,
#year,
#total.
#Display the following information as the result of the summary:
#total amount of loans, average loan amount, total number of given loans.

select extract(year from date) as year,
       quarter(date) as quarter_nr,
       extract(month from date) as month,
       sum(amount) as total_amount,
       avg(amount) as amount_mean,
       count(loan_id) as total_number
from loan
group by year, quarter_nr, month
with rollup
order by year desc, quarter_nr desc, month desc;


#Loan status: which statuses represent repaid loans and which represent unpaid loans.
#682 granted loans in the database, of which 606 have been repaid and 76 have not.

select status, count(status) as status_count
from loan
group by status
order by status;


# Analysis of accounts
# Write a query that ranks accounts according to the following criteria: number of given loans (decreasing),
# amount of given loans (decreasing), average loan amount. Only fully paid loans are considered.

select account_id,
       count(loan_id) as given_loans,
       sum(amount) as total_amount,
       avg(amount) as amount_mean,
       status
from loan
where status in ("A", "C")
group by account_id, status
order by given_loans desc, total_amount desc, amount_mean;

#Fully paid loans: Find out the balance of repaid loans, divided by client gender.
#verze se zobrazením dle statusu půjčky
select c.gender, sum(l.amount) as total_amount, l.status
from loan as l
         join account as a using (account_id)
         join disp as d using (account_id)
         join client as c using (client_id)
where l.status in ("A", "C")
group by c.gender, l.status;

#verze bez statusu, jen dle genderu
select c.gender, sum(l.amount) as total_amount
from loan as l
         join account as a using (account_id)
         join disp as d using (account_id)
         join client as c using (client_id)
where l.status in ("A", "C")
group by c.gender;

# ověření
select sum(amount)
from loan
where status in ("A", "C");
#částky jsou rozdílné - kde je chyba ??
# Pro jednu půjčku je jedno account_id a obráceně.

select loan_id, count(account_id)
from loan
group by loan_id;

select account_id, count(loan_id)
from loan
group by account_id;

# ověření, že pro jeden účet je jeden záznam v tabulce disp
select account_id, count(disp_id)
from disp
group by account_id;
#pro jeden účet může být více disponentů, což asi způsobuje chybu v našem kódu. Zobrazení typu disponentů.

select account_id, count(disp.disp_id), type
from disp
group by disp.account_id, type
order by account_id;
#budeme přidávat podmínku typu disponenta "owner"

#finální kód
select c.gender, sum(l.amount) as total_amount
from loan as l
         join account as a using (account_id)
         join disp as d using (account_id)
         join client as c using (client_id)
where l.status in ("A", "C")
  and d.type = "owner"
group by c.gender;
#výsledek konečně sedí

#verze s rozdělením i dle kategorie půjčky
select c.gender, sum(l.amount) as total_amount, l.status
from loan as l
         join account as a using (account_id)
         join disp as d using (account_id)
         join client as c using (client_id)
where l.status in ("A", "C")
  and d.type = "owner"
group by c.gender, l.status;


# Client analysis - part 1: Who has more repaid loans - women or men?
# What is the average age of the borrower divided by gender?

select c.gender,
       count(l.loan_id) as loans_number,
       avg(year(now()) - year(c.birth_date)) as age
from loan as l
         join account as a using (account_id)
         join disp as d using (account_id)
         join client as c using (client_id)
where l.status in ("A", "C")
  and d.type = "owner"
group by c.gender;

# Client analysis - part 2: Make analyses that answer the questions:
# which area has the most clients,
# in which area the highest number of loans was paid,
# in which area the highest amount of loans was paid.
# Select only owners of accounts as clients.

select di.a3 as region,
       count(c.client_id) as number_clients,
       count(l.loan_id) as number_loans,
       sum(l.amount) as sum_loans
from client as c
         join district as di using (district_id)
         join disp as d using (client_id)
         join account as a using (account_id)
         join loan as l using (account_id)
where d.type = 'owner'
  and l.status in ('A', 'C')
group by region
order by number_clients desc, number_loans desc, sum_loans desc;
# south Moravia má největší počet zaplacených půjček, největší počet klientů a největší objem zaplacených půjček

#verze přes loan, ale zde vychází jiný počet a nějak se mění regiony- regiony se mění kvůli navázání district na account a na to pak client
#musí být district na client
select di.a3 as region,
       count(c.client_id) as number_clients,
       count(l.loan_id) as number_loans,
       sum(l.amount) as sum_loans
from loan as l
         join account as a using (account_id)
         join district as di using (district_id)
         join disp as d using (account_id)
         join client as c using (client_id)
where l.status in ("A", "C")
  and d.type = "owner"
group by region
order by number_clients desc, number_loans desc, sum_loans desc;

# správná verze
select di.a3 as region,
       count(distinct(c.client_id)) as number_clients,
       count(l.loan_id) as number_loans,
       sum(l.amount) as sum_loans
from loan as l
         join account as a using (account_id)
         join disp as d using (account_id)
         join client as c using (client_id)
         join district as di on di.district_id= c.district_id
where l.status in ("A", "C")
  and d.type = "owner"
group by region
order by number_clients desc, number_loans desc, sum_loans desc;


# Client analysis - part 3
# Use the query created in the previous task and modify it to determine the percentage of each district in the total amount
# of loans granted.

select distinct(di.a3) as region,
       count(c.client_id) over (fce) as number_clients,
       count(l.loan_id) over (fce) as number_loans,
       sum(l.amount) over (fce) as sum_loans,
       round(sum(l.amount) over (fce) / sum(l.amount) over() * 100, 2) as amount_share_perc
from client as c
         join district as di using (district_id)
         join disp as d using (client_id)
         join account as a using (account_id)
         join loan as l using (account_id)
where d.type = 'owner'
  and l.status in ('A', 'C')
window fce as (partition by di.a3)
order by number_clients desc, number_loans desc, sum_loans desc;

# Selection - part 1
# Check the database for the clients who meet the following results:
# their account balance is above 1000,
# they have more than 5 loans,
# they were born after 1990.
# And we assume that the account balance is loan amount - payments.

select c.*,
       (l.amount - l.payments) as balance
from client as c
join district as d using (district_id)
join account as a using (district_id)
join loan as l using (account_id)
where (l.amount - l.payments) > 1000
and (extract(year from c.birth_date)) > 1990
group by c.client_id, l.amount, l.payments
having count(l.loan_id) > 5;

# Selection - part 2
# From the previous exercise you probably already know that there are no customers who meet the requirements.
# Make an analysis to determine which condition caused the empty results.
Nikdo není narozen po roce 1990 a myslím, že i nikdo nemá více jak 5 půjček.


# Expiring cards
# Write a procedure to refresh the table you created (you can call it e.g. cards_at_expiration) containing the following columns:
# client_id,
# card_id,
# expiration_date - assume that the card can be active for 3 years after issue date,
# client_address (column A3 is enough).

create table if not exists card_at_expiration as
select c.client_id as client_id,
       card.card_id as card_id,
       adddate(card.issued, interval 3 year) as expiration_date,
       di.a3 as client_address
from client as c
         join district as di using (district_id)
         join disp as d using (client_id)
         join card using (disp_id);

drop procedure table_filling;
delimiter $$
CREATE PROCEDURE table_filling()
BEGIN
    truncate table card_at_expiration;
    insert into card_at_expiration (client_id, card_id, expiration_date, client_address)
    select c.client_id, card.card_id, adddate(card.issued, interval 3 year), di.a3
    from client as c
             join district as di using (district_id)
             join disp as d using (client_id)
             join card using (disp_id);
END$$

delimiter ;
call table_filling();
select *
from card_at_expiration;


#verze pro vkládání hodnot
drop procedure table_filling_1;
delimiter $$
CREATE PROCEDURE table_filling_1(IN p_client_id INT, IN p_card_id INT, IN p_expiration_date DATE,
                                 IN p_client_address varchar(100))
BEGIN
    truncate table card_at_expiration;
    insert into card_at_expiration (client_id, card_id, expiration_date, client_address)
    values (p_client_id, p_card_id, adddate(p_expiration_date, interval 3 year), p_client_address);
END$$

delimiter ;
call table_filling_1(3, 0, '2024-10-11', 'souht Moravia');
select *
from card_at_expiration;

