with 
source as (
      select * 
      from {{ source('dashboard', 'users') }}
),

renamed as (
    select
        id                          as user_id,
        studio_person_id,
        sign_in_count,
        current_sign_in_at,
        last_sign_in_at,
        created_at,
        updated_at,        
        gender,
        locale,
        birthday,
        user_type,
        school_info_id,
        total_lines,
        active                      as is_active,
        deleted_at,
        purged_at,
        urm                         as is_urg, -- (js) new convention
        races,
        primary_contact_info_id

    from source
)

select * 
from renamed