create table notifications (
  id uuid primary key default gen_random_uuid(),
  channel notification_channel not null,
  recipient text not null,
  subject text,
  body text not null,
  status notification_status default 'pending',
  reference_type text,
  reference_id uuid,
  error_message text,
  created_at timestamptz default now()
);
