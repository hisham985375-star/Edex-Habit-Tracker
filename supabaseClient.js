const SUPABASE_URL = 'https://gcidzmpwnqbceftdtvxw.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdjaWR6bXB3bnFiY2VmdGR0dnh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NjE3NDYsImV4cCI6MjA5ODUzNzc0Nn0.rui7VgyIhLFlp3f8lv7-X0Upcw8BjHH6meofKL4JkzI';

// Initialize the Supabase client
// This assumes the Supabase CDN script is loaded before this file
const db = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
