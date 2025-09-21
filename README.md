# TurboNursey (Sinatra + MongoDB)

A minimal Sinatra app with:
- QR-code user login (single-use token)
- Rooms CRUD: datetime_stamp, ward, patient, nurse_or_hca, mood, sleeping_awake
- Answers stored in a separate MongoDB collection linked by room_id

## Requirements

- Ruby 3.4.x
- Bundler (`gem install bundler`)
- MongoDB (local or cloud)
- Git (optional)

## Getting Started

1) Clone and install gems
