with amp_events as (
    select * 
    from {{ ref('base_amplitude__active_teacher_events') }}
)
select
    -- user ids and event time and type
    amplitude_id,
    user_id cdo_user_id,
    event_id, -- I don't know what this is, yet
    event_time,
    event_type,

    -- json blobs with data and info
    data,
    event_properties,
    user_properties,

    -- user's system/device info
    device_family,
    device_type,
    os_name,

    -- region location info
    dma,
    city,
    region, --state, if US
    lower(country) as country,      -- lower to align with user_geos
    case 
        when lower(country) = 'united states' then 'us' 
        when lower(country) <> 'united states' then 'intl'
        else null
    end us_intl,
    language
from amp_events