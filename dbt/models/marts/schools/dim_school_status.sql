{# Notes:
Design: 1 row per school, school_year, churn_status
Logic: we can determine status based on three properties we can compute for every user|school_year as a binary:
    - 0/1 they are active this school_year - (A)ctive
    - 0/1 they were active in the previous school_year - (P)rev year
    - 0/1 they have ever been active in ANY school_year prior, incl. prev year - (E)ver before

    These 3 values can be combined into an ordered 3-char string representing the concatenated true/false combinations 
    for Active|Prev|Ever e.g. "101" means: ( Active = true AND Prev year = false AND Ever before = true )

    - '000' (0) = 'market'              -- Not active now + never been active
    - '001' (1) = 'inactive churn'      -- NOT active + NOT active prev year + active ever before
    - '010' (2) = '<impossible status>' -- should not be possible, active in the prev year should imply active ever before
    - '011' (3) = 'inactive this year'  -- NOT active + active prev year + (active ever before implied)
    - '100' (4) = 'active new'          -- active this year + NOT active last year + NOT active ever before
    - '101' (5) = 'active reacquired'   -- Active this year + NOT active last year + active in the past
    - '110' (6) = '<impossible status>' -- impossible for same reason as status (2)
    - '111' (7) = 'active retained'     -- active this year + active last year + (active ever before implied) 
#}

with 

all_schools as (
    select school_id
    from {{ ref('dim_schools') }}
),

school_years as (
    select * 
    from {{ ref('int_school_years') }}
),

all_schools_sy as (
    select 
        all_schools.school_id,
        school_years.school_year
    from all_schools 
    cross join school_years
),

teacher_school_changes as (
    select *
    from {{ ref('int_teacher_schools_historical') }}
),

teacher_active_courses as (
    select 
        distinct teacher_id,
        school_year,
        course_name,
        section_started_at
    from {{ref('int_active_sections')}}
),

teacher_active_courses_with_sy as (

    select
        tac.teacher_id,
        tac.school_year,
        tac.course_name,
        tac.section_started_at,
        tsc.school_id
    from teacher_active_courses tac 
    join school_years sy
        on tac.school_year = sy.school_year
    join teacher_school_changes tsc 
        on tac.teacher_id = tsc.teacher_id 
        and sy.ended_at between tsc.started_at and tsc.ended_at 
),

started_schools as (
    select 
        school_id,
        school_year,
        min(section_started_at) as school_started_at,
        listagg( distinct course_name, ', ') within group (order by course_name) active_courses
    from teacher_active_courses_with_sy
    group by 1, 2
)
, active_status_simple as (
    select 
        all_schools_sy.school_id,
        all_schools_sy.school_year,
        
        case when -- for a school to be active it has to have started a course that is NOT hoc-only
            started_schools.school_id is not null 
            and started_schools.active_courses <> 'hoc' then 1 
            else 0 
        end as is_active,

        started_schools.school_started_at,
        started_schools.active_courses
    from all_schools_sy 
    left join started_schools
        on started_schools.school_id = all_schools_sy.school_id 
        and started_schools.school_year = all_schools_sy.school_year
)
, full_status as (
    -- Determine the active status for each school in each school year

    select
        school_id,
        school_year,
        is_active,
        coalesce(
            lag(is_active, 1) 
                over (partition by school_id order by school_year) 
            , 0
        ) as prev_year_active,
        coalesce( --force any NULL to be 0 for this function
            max(is_active) 
                over (partition by school_id order by school_year rows between unbounded preceding and 1 preceding)
            , 0
        ) as ever_active_before,
        (is_active || prev_year_active || ever_active_before) status_code,
        school_started_at,
        active_courses
    from
        active_status_simple

), 

final as (

    select
        school_id,
        school_year,
        case 
            when status_code = '000' then 'market'
            when status_code = '011' then 'inactive this year'
            when status_code = '001' then 'inactive churn'
            when status_code = '100' then 'active new'
            when status_code = '101' then 'active reacquired'
            when status_code = '111' then 'active retained'
            else null 
        end as status,

            -- (js): impossible = "i'm possible"
            -- when status_code = '110' then '<impossible status>' 
            -- when status_code = '010' then '<impossible status>'
        status_code,
        school_started_at,
        active_courses
        from full_status
    order by
        school_id, 
        school_year )
        
select *
from final