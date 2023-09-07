with 
source as (
      select * from {{ source('dashboard', 'followers') }}
),

renamed as (
    select
        id as follower_id,
        student_user_id,
        section_id,
        created_at,
        updated_at
        deleted_at
    from source
)

select * from renamed