-- 049: Captain available orders — oldest created_at first (FIFO queue).
-- Depends on: 028 captain_list_available_orders

create or replace function public.captain_list_available_orders()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  prof public.profiles;
  result jsonb;
begin
  prof := public._require_active_captain();

  if not public.captain_has_active_subscription(prof.id) then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_data order by created_at asc), '[]'::jsonb)
  into result
  from (
    select jsonb_build_object(
      'id', o.id,
      'request_number', o.request_number,
      'order_type_name', o.order_type_name,
      'details', o.details,
      'destination_label', public._delivery_destination_label(
        o.destination_type, o.destination_address
      ),
      'delivery_fee_iqd', o.delivery_fee_iqd,
      'created_at', o.created_at,
      'expires_at', o.expires_at
    ) as row_data,
    o.created_at
    from public.delivery_orders o
    where o.status = 'pending'
      and o.captain_id is null
      and o.expires_at > now()
  ) q;

  return result;
end;
$$;

revoke all on function public.captain_list_available_orders() from public;
grant execute on function public.captain_list_available_orders() to authenticated;
