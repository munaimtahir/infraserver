import { createApp } from 'vue'; // Import createApp directly
import './design-tokens.css';

import App from './App.vue';
import GlobalStatusBar from './components/GlobalStatusBar.vue';
import KPIMetricsRow from './components/KPIMetricsRow.vue';
import SystemsGrid from './components/SystemsGrid.vue';
import SystemCard from './components/SystemCard.vue';
import OperationsDrawer from './components/OperationsDrawer.vue';
import HealthBadge from './components/HealthBadge.vue';
import CollapsibleSection from './components/CollapsibleSection.vue';
import ConfirmationModal from './components/ConfirmationModal.vue';

const app = createApp(App);

app.component('GlobalStatusBar', GlobalStatusBar);
app.component('KPIMetricsRow', KPIMetricsRow);
app.component('SystemsGrid', SystemsGrid);
app.component('SystemCard', SystemCard);
app.component('OperationsDrawer', OperationsDrawer);
app.component('HealthBadge', HealthBadge);
app.component('CollapsibleSection', CollapsibleSection);
app.component('ConfirmationModal', ConfirmationModal);


app.mount('#app');
