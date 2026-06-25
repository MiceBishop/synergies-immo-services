create type unit_type as enum ('apartment', 'office', 'shop', 'parking', 'storage');
create type unit_status as enum ('vacant', 'occupied', 'under_renovation');
create type lease_status as enum ('active', 'expired', 'terminated', 'draft');
create type payment_method as enum ('cash', 'bank_transfer', 'check', 'direct_debit');
create type payment_status as enum ('paid', 'partial', 'unpaid', 'overdue');
create type expense_type as enum ('water', 'electricity', 'syndicate', 'maintenance', 'tax', 'other');
create type document_type as enum ('national_id', 'business_registration', 'tax_id', 'signed_lease', 'receipt', 'invoice', 'other');
create type notification_channel as enum ('email', 'sms', 'whatsapp');
create type notification_status as enum ('pending', 'sent', 'failed');
