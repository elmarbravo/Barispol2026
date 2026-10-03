-- Telemóvel do próprio e telemóvel de familiar (03-10-2026, Elmar: «Avante
-- o 2»; proposta do apuramento do inquérito de 16-09-2026: em seis casos o
-- número do paciente era de um familiar). Na marcação, «contacto» passa a ser
-- o telemóvel do próprio (é o que se usa para ligar, para o lembrete e para o
-- inquérito; tel9 sai dele); o do familiar fica à parte, com quem é.
alter table public.marcacoes add column if not exists contacto_familiar text;
alter table public.marcacoes add column if not exists familiar_quem text;
