-- Model: dim_schools
-- Scope: all dimensions we have/need for schools; one row per school + school_year
with
schools as (
    select *
    from {{ ref('stg_dashboard__schools') }}
),

school_districts as (
    select *
    from {{ ref('stg_dashboard__school_districts') }}
),

school_stats_by_years as (
    select *, 
        row_number() 
            over(
                partition by school_id 
                order by school_year desc) as row_num

    from {{ ref('stg_dashboard__school_stats_by_years') }}
),

combined as (
    select
        -- schools
        schools.school_id,
        schools.city,
        schools.state,
        schools.zip,

        school_stats_by_years.school_year   as most_recent_survey_school_year,
        school_stats_by_years.is_stage_el,
        school_stats_by_years.is_stage_mi,
        school_stats_by_years.is_stage_hi,
        
        (
            (case when school_stats_by_years.is_stage_el = 1 then 'el' else '__' end ) ||
            (case when school_stats_by_years.is_stage_mi = 1 then 'mi' else '__' end ) ||
            (case when school_stats_by_years.is_stage_hi = 1 then 'hi' else '__' end ) 
        ) as school_level_simple,

        school_stats_by_years.is_rural,
        school_stats_by_years.is_title_i,
        school_stats_by_years.community_type,

        schools.school_category,
        schools.school_name,
        schools.school_type,
        case when total_frl_eligible_students / total_students::float > 0.5
            then 1 else 0 
        end as is_high_needs,

        schools.last_known_school_year_open,

        --school_districts
        school_districts.school_district_id,
        school_districts.school_district_name,

        -- nces school metrics
        school_stats_by_years.total_students,
        school_stats_by_years.count_student_am,
        school_stats_by_years.count_student_as,
        school_stats_by_years.count_student_hi,
        school_stats_by_years.count_student_bl,
        school_stats_by_years.count_student_wh,
        school_stats_by_years.count_student_hp,
        school_stats_by_years.count_student_tr,
        school_stats_by_years.total_frl_eligible_students,

        nullif(
            sum(school_stats_by_years.count_student_am 
                + school_stats_by_years.count_student_hi
                + school_stats_by_years.count_student_bl
                + school_stats_by_years.count_student_hp)
            ,0) as total_urg_no_tr_students,

        nullif(
            sum(school_stats_by_years.count_student_am
                + school_stats_by_years.count_student_hi
                + school_stats_by_years.count_student_bl
                + school_stats_by_years.count_student_hp
                + school_stats_by_years.count_student_tr)
            ,0) as total_urg_students,

        nullif(
            sum(school_stats_by_years.count_student_am  
                + school_stats_by_years.count_student_as  
                + school_stats_by_years.count_student_hi  
                + school_stats_by_years.count_student_bl  
                + school_stats_by_years.count_student_wh  
                + school_stats_by_years.count_student_hp
                + school_stats_by_years.count_student_tr)
            ,0) as total_students_calculated,
        
        -- calculations 
        total_urg_students / total_students_calculated::float as urg_percent,

        total_urg_no_tr_students / total_students_calculated::float as urg_no_tr_percent,
        
        total_frl_eligible_students / total_students::float as frl_eligible_percent,
        
        -- dates 
        min(schools.created_at) as school_created_at,
        max(schools.updated_at) as school_last_updated_at

    from schools
    left join school_stats_by_years
        on schools.school_id = school_stats_by_years.school_id
        and school_stats_by_years.row_num = 1
    left join school_districts
        on schools.school_district_id = school_districts.school_district_id
    {{ dbt_utils.group_by(28) }}
)

select *
from combined