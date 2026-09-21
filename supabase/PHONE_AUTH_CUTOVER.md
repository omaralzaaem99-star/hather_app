# Phone Auth + OTPIQ Send SMS Hook — operator checklist

## Preflight (SQL Editor)

1. Run `supabase/sql/006_preflight_existing_users.sql`
2. If `internal_email_users` > 0:
   - Run `supabase/scripts/migrate_email_users_to_phone.ts` with service role **locally**
   - Confirm Same UUID preserved
3. Apply `supabase/sql/006_phone_auth_cutover.sql`
4. After cutover is live, apply `supabase/sql/007_remove_legacy_custom_otp.sql`

## Deploy Edge Functions

```bash
supabase functions deploy auth-send-sms --project-ref gonlutyrhccmdpdwqdhk
supabase secrets set OTPIQ_API_KEY=...
# After creating the Auth Hook in Dashboard, set:
supabase secrets set SEND_SMS_HOOK_SECRET=v1,whsec_...
```

Legacy `send-otp` / `verify-otp` were removed from the repo — delete them from the
Supabase project dashboard/CLI if they are still deployed remotely.

## Dashboard (required)

See migration report: Phone Provider + Send SMS Hook URL → auth-send-sms.
