
    
    

select
    student_id as unique_field,
    count(*) as n_records

from "dev"."dbt_jordan"."dim_students"
where student_id is not null
group by student_id
having count(*) > 1


