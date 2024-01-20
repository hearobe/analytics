with 
source as (
    select * 
    from "dashboard"."dashboard_production_pii"."pd_international_opt_ins"
),

renamed as (
    select 
        id as international_opt_in_id,
        user_id,
        form_data,
        created_at,
        updated_at
    from source 
)

select *
from renamed