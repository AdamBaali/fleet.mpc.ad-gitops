<?php
// The lab Fleet as the service provider for end user authentication. The entity ID must equal
// org_settings.mdm.end_user_authentication.entity_id in default.yml.
$metadata['fleet-mpc-ad-end-users'] = array(
    'AssertionConsumerService' => [
        'https://fleet.mpc.ad/api/v1/fleet/mdm/sso/callback',
    ],
    // Fleet requires the email as Name ID.
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'simplesaml.nameidattribute' => 'email',
);
